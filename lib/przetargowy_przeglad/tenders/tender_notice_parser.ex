defmodule PrzetargowyPrzeglad.Tenders.TenderNoticeParser do
  @moduledoc """
  Parser for extracting contract values from tender notices (ezamowienia.gov.pl)
  """

  @doc """
  Extracts contract values from htmlBody field.
  Returns a list of maps with part number and value.

  ## Example

      iex> TenderNoticeParser.extract_contract_values(html_body)
      [
        %{part: 1, value: 21918.60, currency: "PLN"},
        %{part: 2, value: 6260.09, currency: "PLN"},
        ...
      ]
  """
  def extract_contract_values(html_body) when is_binary(html_body) do
    # Decode HTML entities if needed
    html = decode_html_entities(html_body)

    # Pattern for: "8.2.) Wartość umowy/umowy ramowej: 21918,60 PLN"
    regex = ~r/8\.2\.\)\s*Wartość umowy\/umowy ramowej:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu

    regex
    |> Regex.scan(html)
    |> Enum.with_index(1)
    |> Enum.map(fn {[_full, value_str, currency], index} ->
      %{
        part: index,
        value: parse_value(value_str),
        currency: String.upcase(currency)
      }
    end)
  end

  @doc """
  Extracts total contract value (suma wszystkich części).
  """
  def total_contract_value(html_body) do
    html_body
    |> extract_contract_values()
    |> Enum.reduce(0.0, fn %{value: v}, acc -> acc + v end)
    |> Float.round(2)
  end

  @doc """
  Extracts estimated value from section 4.3 (wartość zamówienia).
  """
  def extract_estimated_value(html_body) when is_binary(html_body) do
    html = decode_html_entities(html_body)

    # Pattern for: "4.3.) Wartość zamówienia: 108335,82 PLN"
    regex = ~r/4\.3\.\)\s*Wartość zamówienia:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu

    case Regex.run(regex, html) do
      [_full, value_str, currency] ->
        %{value: parse_value(value_str), currency: String.upcase(currency)}

      nil ->
        %{}
    end
  end

  @doc """
  Extracts part values from section 4.5.5 (wartość części - estimated).
  """
  def extract_part_estimated_values(html_body) when is_binary(html_body) do
    html = decode_html_entities(html_body)

    # Pattern for: "4.5.5.) Wartość części: 19066,67 PLN"
    regex = ~r/4\.5\.5\.\)\s*Wartość części:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu

    regex
    |> Regex.scan(html)
    |> Enum.with_index(1)
    |> Enum.map(fn {[_full, value_str, currency], index} ->
      %{
        part: index,
        estimated_value: parse_value(value_str),
        currency: String.upcase(currency)
      }
    end)
  end

  @doc """
  Extracts winning offer prices from section 6.4.
  """
  def extract_winning_prices(html_body) when is_binary(html_body) do
    html = decode_html_entities(html_body)

    # Pattern for: "6.4.) Cena lub koszt oferty wykonawcy, któremu udzielono zamówienia: 21918,60 PLN"
    regex = ~r/6\.4\.\)[^:]*:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu

    regex
    |> Regex.scan(html)
    |> Enum.with_index(1)
    |> Enum.map(fn {[_full, value_str, currency], index} ->
      %{
        part: index,
        winning_price: parse_value(value_str),
        currency: String.upcase(currency)
      }
    end)
  end

  @doc """
  Extracts lowest and highest offer prices from sections 6.2 and 6.3.
  """
  def extract_price_range(html_body) when is_binary(html_body) do
    html = decode_html_entities(html_body)

    # Lowest price: 6.2.)
    lowest_regex = ~r/6\.2\.\)[^:]*najniższą[^:]*:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu
    # Highest price: 6.3.)
    highest_regex = ~r/6\.3\.\)[^:]*najwyższą[^:]*:\s*(?:<[^>]+>)?\s*([\d\s]+[,\.]\d{2})\s*(PLN|EUR)/iu

    lowest_matches = Regex.scan(lowest_regex, html)
    highest_matches = Regex.scan(highest_regex, html)

    lowest_matches
    |> Enum.zip(highest_matches)
    |> Enum.with_index(1)
    |> Enum.map(fn {{[_, low_val, low_curr], [_, high_val, _high_curr]}, index} ->
      %{
        part: index,
        lowest_price: parse_value(low_val),
        highest_price: parse_value(high_val),
        currency: String.upcase(low_curr)
      }
    end)
  end

  @doc """
  Extracts procedure results from JSON field.
  Returns list of statuses per part: :contract_signed or :cancelled
  """
  def extract_procedure_results(tender_json) when is_map(tender_json) do
    procedure_result = Map.get(tender_json, "procedureResult", "")

    if procedure_result == nil do
      []
    else
      procedure_result
      |> String.split(";")
      |> Enum.map(fn
        "zawarcieUmowy" -> :contract_signed
        "uniewaznienie" -> :cancelled
        other -> {:unknown, other}
      end)
    end
  end

  @doc """
  Extracts cancellation reasons from htmlBody.
  """
  def extract_cancellation_reasons(html_body) when is_binary(html_body) do
    html = decode_html_entities(html_body)

    # Pattern for part headers followed by cancellation
    # Looking for "Część N" followed by cancellation info
    regex = ~r/Część\s+(\d+).*?5\.2\.\)\s*Podstawa prawna unieważnienia[^:]*:\s*(?:<[^>]+>)?\s*([^<]+)/isu

    regex
    |> Regex.scan(html)
    |> Enum.map(fn [_full, part_num, reason] ->
      %{
        part: String.to_integer(part_num),
        cancellation_reason: String.trim(reason)
      }
    end)
  end

  @doc """
  Combines all extracted data into a comprehensive summary.
  Handles both successful contracts and cancelled parts.
  """
  def parse_contract(tender_json) when is_map(tender_json) do
    html_body = Map.get(tender_json, "htmlBody", "")
    contractors = Map.get(tender_json, "contractors", []) || []

    procedure_results = extract_procedure_results(tender_json)
    contract_values = extract_contract_values(html_body)
    winning_prices = extract_winning_prices(html_body)
    price_ranges = extract_price_range(html_body)
    cancellations = extract_cancellation_reasons(html_body)

    # Track which contract value index we're on (only for non-cancelled parts)
    {parts, _} =
      contractors
      |> Enum.with_index(1)
      |> Enum.map_reduce(1, fn {contractor, part_index}, contract_idx ->
        status = Enum.at(procedure_results, part_index - 1, :unknown)
        is_cancelled = status == :cancelled || is_nil(Map.get(contractor, "contractorName"))

        if is_cancelled do
          cancellation = Enum.find(cancellations, %{}, &(&1.part == part_index))

          part = %{
            part: part_index,
            status: :cancelled,
            contractor_name: nil,
            contractor_city: nil,
            contractor_nip: nil,
            contract_value: nil,
            winning_price: nil,
            lowest_price: nil,
            highest_price: nil,
            cancellation_reason: Map.get(cancellation, :cancellation_reason),
            currency: "PLN"
          }

          {part, contract_idx}
        else
          contract = Enum.at(contract_values, contract_idx - 1, %{})
          winning = Enum.at(winning_prices, contract_idx - 1, %{})
          range = Enum.at(price_ranges, contract_idx - 1, %{})

          part = %{
            part: part_index,
            status: :contract_signed,
            contractor_name: Map.get(contractor, "contractorName"),
            contractor_city: Map.get(contractor, "contractorCity"),
            contractor_nip: Map.get(contractor, "contractorNationalId"),
            contract_value: Map.get(contract, :value),
            winning_price: Map.get(winning, :winning_price),
            lowest_price: Map.get(range, :lowest_price),
            highest_price: Map.get(range, :highest_price),
            cancellation_reason: nil,
            currency: Map.get(contract, :currency, "PLN")
          }

          {part, contract_idx + 1}
        end
      end)

    %{
      estimated_values: html_body |> extract_part_estimated_values() |> Enum.map(& &1.estimated_value),
      estimated_value: html_body |> extract_estimated_value() |> Map.get(:value, nil),
      total_contract_value: total_contract_value(html_body),
      total_contractors_contracts_count: length(contractors),
      cancelled_count: Enum.count(procedure_results, &(&1 == :cancelled)),
      contractors_contract_details: parts
    }
  end

  # Private helpers

  defp parse_value(value_str) do
    value_str
    # Remove spaces
    |> String.replace(~r/\s/, "")
    # Polish decimal separator
    |> String.replace(",", ".")
    |> Float.parse()
    |> case do
      {value, _} -> Float.round(value, 2)
      :error -> 0.0
    end
  end

  defp decode_html_entities(html) do
    html
    |> String.replace("\\u003C", "<")
    |> String.replace("\\u003E", ">")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end
end
