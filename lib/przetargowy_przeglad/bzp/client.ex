defmodule PrzetargowyPrzeglad.Bzp.Client do
  @moduledoc """
  Client for fetching tenders from the BZP API (ezamowienia.gov.pl).

  ## Usage

      BzpClient.fetch_tenders_notices()
      BzpClient.fetch_tenders_notices(cpv_code: "45000000-7", notice_type: "ContractNotice")
      BzpClient.fetch_all_recent(days: 7)
  """

  require Logger

  @base_url "https://ezamowienia.gov.pl/mo-board/api/v1/notice"
  @default_page_size 100
  @timeout 30_000
  @retry_attempts 3
  @retry_delay 1_000

  @doc """
  Fetches tenders notices published between the given dates.

  ## Options
  - `:object_id` - specific tender notice ID to fetch
  - `:publication_date_from` - date from (YYYY-MM-DD)
  - `:publication_date_to` - date to (YYYY-MM-DD)
  """
  def fetch_tenders_notices(object_id, publication_date_from, publication_date_to) do
    params = build_query_params(object_id, publication_date_from, publication_date_to)

    Logger.info(
      "BZP API: Fetching tenders notices from #{publication_date_from} to #{publication_date_to} from object_id #{inspect(object_id)}"
    )

    case make_request_with_retry(params) do
      {:ok, response} -> parse_response(response, 0)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches all pages up to the limit.
  """
  def fetch_all_tender_notices(publication_date_from, publication_date_to) do
    fetch_all_tender_notices(nil, publication_date_from, publication_date_to, [])
  end

  defp fetch_all_tender_notices(object_id, publication_date_from, publication_date_to, acc) do
    case fetch_tenders_notices(object_id, publication_date_from, publication_date_to) do
      {:ok, %{tenders: []}} ->
        Logger.info("BZP API: No more results.")
        {:ok, acc}

      {:ok, %{tenders: tenders}} ->
        Logger.info("BZP API: Got #{length(tenders)} tenders")
        # Rate limiting
        Process.sleep(500)
        last_tender = List.last(tenders)
        next_object_id = last_tender.object_id
        fetch_all_tender_notices(next_object_id, publication_date_from, publication_date_to, acc ++ tenders)

      {:error, reason} ->
        Logger.error("BZP API: Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_query_params(object_id, publication_date_from, publication_date_to) do
    maybe_add(
      %{
        "PageSize" => @default_page_size,
        "PublicationDateFrom" => publication_date_from,
        "PublicationDateTo" => publication_date_to,
        "NoticeType" => "TenderResultNotice"
      },
      "SearchAfter",
      object_id
    )
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
      estimated_values: estimated_values,
      estimated_value: estimated_value,
      total_contract_value: total_contract_value,
      total_contractors_contracts_count: total_contractors_contracts_count,
      cancelled_count: cancelled_count,
      contractors_contract_details: contractors_contract_details
    } = PrzetargowyPrzeglad.Tenders.TenderNoticeParser.parse_contract(raw)

    %{
      client_type: raw["clientType"],
      order_type: raw["orderType"],
      tender_type: raw["tenderType"],
      notice_type: raw["noticeType"],
      notice_number: raw["noticeNumber"] || raw["bzpNumber"],
      bzp_number: raw["bzpNumber"],
      is_tender_amount_below_eu: raw["isTenderAmountBelowEU"],
      publication_date: raw["publicationDate"],
      order_object: raw["orderObject"],
      cpv_codes: String.split(raw["cpvCode"], ","),
      submitting_offers_date: raw["submittingOffersDate"],
      procedure_result: raw["procedureResult"],
      organization_name: raw["organizationName"],
      organization_city: raw["organizationCity"],
      organization_province: raw["organizationProvince"],
      organization_country: raw["organizationCountry"],
      organization_national_id: raw["organizationNationalId"],
      organization_id: raw["organizationId"],
      tender_id: raw["tenderId"],
      html_body: sanitize_string(raw["htmlBody"]),
      contractors:
        Enum.map(raw["contractors"] || [], fn contractor ->
          %{
            contractor_name: contractor["contractorName"],
            contractor_city: contractor["contractorCity"],
            contractor_province: contractor["contractorProvince"],
            contractor_country: contractor["contractorCountry"],
            contractor_national_id: contractor["contractorNationalId"]
          }
        end),
      object_id: raw["objectId"],
      estimated_values: estimated_values,
      estimated_value: estimated_value,
      total_contract_value: total_contract_value,
      total_contractors_contracts_count: total_contractors_contracts_count,
      cancelled_count: cancelled_count,
      contractors_contract_details: contractors_contract_details
    }
  end

  defp sanitize_string(nil), do: nil
  defp sanitize_string(str) when is_binary(str), do: String.replace(str, <<0>>, "")
end
