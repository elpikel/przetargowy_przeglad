defmodule PrzetargowyPrzeglad.Bzp.Client do
  @moduledoc """
  Client for fetching tenders from the BZP API (ezamowienia.gov.pl).

  ## Usage

      BzpClient.fetch_tenders()
      BzpClient.fetch_tenders(cpv_code: "45000000-7", notice_type: "ContractNotice")
      BzpClient.fetch_all_recent(days: 7)
  """

  require Logger

  @base_url "https://ezamowienia.gov.pl/mo-board/api/v1/Board/Search"
  @default_page_size 100
  @timeout 30_000
  @retry_attempts 3
  @retry_delay 1_000

  @doc """
  Fetches a single page of tenders.

  ## Options
  - `:page` - page number (from 0)
  - `:page_size` - number of results per page (max 100)
  - `:publication_date_from` - date from (YYYY-MM-DD)
  - `:publication_date_to` - date to (YYYY-MM-DD)
  - `:cpv_code` - filter by CPV code (e.g., "45000000-7")
  - `:notice_type` - notice type (ContractNotice, TenderResultNotice, etc.)
  """
  def fetch_tenders(opts \\ []) do
    params = build_query_params(opts)

    Logger.info("BZP API: Fetching page #{opts[:page] || 0}")

    case make_request_with_retry(params) do
      {:ok, response} -> parse_response(response, opts[:page] || 0)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches all pages up to the limit.
  """
  def fetch_all_tenders(opts \\ []) do
    max_pages = opts[:max_pages] || 10

    0
    |> Stream.iterate(&(&1 + 1))
    |> Stream.take(max_pages)
    |> Enum.reduce_while({:ok, []}, fn page, {:ok, acc} ->
      opts_with_page = Keyword.put(opts, :page, page)

      case fetch_tenders(opts_with_page) do
        {:ok, %{tenders: []}} ->
          Logger.info("BZP API: No more results at page #{page}")
          {:halt, {:ok, acc}}

        {:ok, %{tenders: tenders}} ->
          Logger.info("BZP API: Got #{length(tenders)} tenders from page #{page}")
          # Rate limiting
          Process.sleep(500)
          {:cont, {:ok, acc ++ tenders}}

        {:error, reason} ->
          Logger.error("BZP API: Error at page #{page}: #{inspect(reason)}")
          {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Fetches tenders from the last N days.
  """
  def fetch_recent(days \\ 7, opts \\ []) do
    date_from = Date.utc_today() |> Date.add(-days) |> Date.to_iso8601()
    date_to = Date.to_iso8601(Date.utc_today())

    opts
    |> Keyword.put(:publication_date_from, date_from)
    |> Keyword.put(:publication_date_to, date_to)
    |> fetch_all_tenders()
  end

  # Private: Query params building

  defp build_query_params(opts) do
    # API uses 1-based page numbering
    page = (opts[:page] || 0) + 1

    params = %{
      "PageNumber" => page,
      "PageSize" => opts[:page_size] || @default_page_size
    }

    params
    |> maybe_add("CpvCode", opts[:cpv_code])
    |> maybe_add("NoticeType", opts[:notice_type])
    |> maybe_add("PublicationDateFrom", opts[:publication_date_from])
    |> maybe_add("PublicationDateTo", opts[:publication_date_to])
    |> maybe_add("ContractingAuthorityName", opts[:authority_name])
    |> maybe_add("SearchPhrase", opts[:search])
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  # Private: HTTP request with retry

  defp make_request_with_retry(params, attempt \\ 1) do
    case make_request(params) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: error_body}} ->
        Logger.warning("BZP API: Status #{status}, body: #{inspect(error_body)}")
        maybe_retry({:error, {:http_error, status}}, params, attempt)

      {:error, reason} ->
        Logger.warning("BZP API: Request failed: #{inspect(reason)}")
        maybe_retry({:error, reason}, params, attempt)
    end
  end

  defp make_request(params) do
    Req.get(@base_url,
      params: params,
      headers: [
        {"Accept", "application/json"},
        {"User-Agent", "PrzetargowyPrzeglad/1.0"}
      ],
      receive_timeout: @timeout
    )
  end

  defp maybe_retry(_error, params, attempt) when attempt < @retry_attempts do
    delay = @retry_delay * attempt
    Logger.info("BZP API: Retrying in #{delay}ms (attempt #{attempt + 1}/#{@retry_attempts})")
    Process.sleep(delay)
    make_request_with_retry(params, attempt + 1)
  end

  defp maybe_retry(error, _params, _attempt), do: error

  # Private: Response parsing

  # API returns a list directly
  defp parse_response(body, page) when is_list(body) do
    tenders = Enum.map(body, &parse_tender/1)

    {:ok,
     %{
       tenders: tenders,
       total: length(tenders),
       page: page
     }}
  end

  defp parse_response(body, page) when is_map(body) do
    tenders =
      body
      |> Map.get("notices", [])
      |> Enum.map(&parse_tender/1)

    {:ok,
     %{
       tenders: tenders,
       total: Map.get(body, "totalCount", length(tenders)),
       page: page
     }}
  end

  defp parse_response(body, page) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_response(decoded, page)
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp parse_tender(raw) do
    %{
      external_id: extract_external_id(raw),
      source: "bzp",
      title: raw["orderObject"] || raw["title"] || raw["noticeTitle"] || "Brak tytułu",
      description: raw["description"] || raw["shortDescription"],
      notice_type: raw["noticeType"],
      notice_number: raw["noticeNumber"] || raw["bzpNumber"],
      contracting_authority_name: extract_authority_name(raw),
      contracting_authority_city: extract_authority_city(raw),
      contracting_authority_region: extract_and_normalize_region(raw),
      estimated_value: parse_value(raw),
      currency: raw["currency"] || "PLN",
      submission_deadline:
        parse_datetime(raw["submittingOffersDate"] || raw["submissionDeadline"] || raw["tenderDeadline"]),
      publication_date: parse_datetime(raw["publicationDate"]),
      cpv_codes: extract_cpv_codes(raw),
      procedure_type: raw["procedureType"] || raw["tenderType"],
      url: extract_url(raw),
      raw_data: raw,
      fetched_at: DateTime.truncate(DateTime.utc_now(), :second)
    }
  end

  # Extraction helpers

  defp extract_external_id(raw) do
    raw["moIdentifier"] || raw["objectId"] || raw["tenderId"] || raw["ocid"] || raw["id"] ||
      raw["noticeId"] || generate_id(raw)
  end

  defp generate_id(raw) do
    data = "#{raw["title"]}#{raw["publicationDate"]}#{raw["contractingAuthorityName"]}"
    :md5 |> :crypto.hash(data) |> Base.encode16(case: :lower) |> String.slice(0, 16)
  end

  defp extract_authority_name(raw) do
    get_in(raw, ["contractingAuthority", "name"]) ||
      raw["contractingAuthorityName"] ||
      raw["organizationName"]
  end

  defp extract_authority_city(raw) do
    raw["organizationCity"] ||
      get_in(raw, ["contractingAuthority", "city"]) ||
      get_in(raw, ["contractingAuthority", "address", "city"]) ||
      raw["contractingAuthorityLocation"]
  end

  defp extract_and_normalize_region(raw) do
    region =
      raw["organizationProvince"] ||
        get_in(raw, ["contractingAuthority", "address", "region"]) ||
        get_in(raw, ["contractingAuthority", "region"]) ||
        raw["region"]

    normalize_region(region)
  end

  defp normalize_region(nil), do: nil

  defp normalize_region(region) when is_binary(region) do
    region
    |> String.downcase()
    |> String.replace(~r/województwo\s*/i, "")
    |> String.trim()
    |> normalize_polish_chars()
  end

  defp normalize_polish_chars(str) do
    str
    |> String.replace("ą", "a")
    |> String.replace("ć", "c")
    |> String.replace("ę", "e")
    |> String.replace("ł", "l")
    |> String.replace("ń", "n")
    |> String.replace("ó", "o")
    |> String.replace("ś", "s")
    |> String.replace("ź", "z")
    |> String.replace("ż", "z")
  end

  defp extract_cpv_codes(raw) do
    cond do
      is_list(raw["cpvCodes"]) -> raw["cpvCodes"]
      is_binary(raw["cpvCode"]) -> [raw["cpvCode"]]
      is_list(raw["cpv"]) -> raw["cpv"] |> Enum.map(& &1["code"]) |> Enum.reject(&is_nil/1)
      true -> []
    end
  end

  defp parse_value(raw) do
    value =
      raw["estimatedValue"] || raw["contractValue"] ||
        get_in(raw, ["value", "amount"])

    case value do
      nil -> nil
      %{"amount" => amount} -> parse_decimal(amount)
      v -> parse_decimal(v)
    end
  end

  defp parse_decimal(nil), do: nil
  defp parse_decimal(v) when is_number(v), do: Decimal.new("#{v}")

  defp parse_decimal(v) when is_binary(v) do
    cleaned = v |> String.replace(~r/[^\d.,]/, "") |> String.replace(",", ".")

    case Decimal.parse(cleaned) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp parse_decimal(_), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(dt) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, datetime, _} ->
        DateTime.truncate(datetime, :second)

      {:error, _} ->
        case Date.from_iso8601(String.slice(dt, 0, 10)) do
          {:ok, date} -> DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
          _ -> nil
        end
    end
  end

  defp parse_datetime(_), do: nil

  defp extract_url(raw) do
    raw["url"] ||
      case raw["bzpNumber"] || raw["noticeNumber"] do
        nil ->
          case extract_external_id(raw) do
            nil -> nil
            id -> "https://ezamowienia.gov.pl/mo-client-board/bzp/notice-details/#{id}"
          end

        bzp_number ->
          "https://ezamowienia.gov.pl/mo-client-board/bzp/notice-details/#{URI.encode(bzp_number)}"
      end
  end
end
