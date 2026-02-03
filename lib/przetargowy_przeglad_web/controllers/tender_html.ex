defmodule PrzetargowyPrzegladWeb.TenderHTML do
  use PrzetargowyPrzegladWeb, :html

  embed_templates "tender_html/*"

  def format_date(nil), do: "-"

  def format_date(datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y")
  end

  def format_value(nil), do: "-"

  def format_value(value) do
    value
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1 ")
  end

  def truncate_text(nil, _length), do: ""
  def truncate_text(string, length) when byte_size(string) <= length, do: string

  def truncate_text(string, length) do
    String.slice(string, 0, length) <> "..."
  end

  def build_url(query, regions, order_types, page) do
    base_params = Enum.filter([q: query, page: page], fn {_k, v} -> v && v != "" && v != 1 end)
    region_params = Enum.map(regions || [], fn r -> {"regions[]", r} end)
    type_params = Enum.map(order_types || [], fn t -> {"order_types[]", t} end)

    params = URI.encode_query(base_params ++ region_params ++ type_params)

    "/tenders?#{params}"
  end

  def region_options do
    [
      {"dolnoslaskie", "Dolnośląskie"},
      {"kujawsko-pomorskie", "Kujawsko-pomorskie"},
      {"lubelskie", "Lubelskie"},
      {"lubuskie", "Lubuskie"},
      {"lodzkie", "Łódzkie"},
      {"malopolskie", "Małopolskie"},
      {"mazowieckie", "Mazowieckie"},
      {"opolskie", "Opolskie"},
      {"podkarpackie", "Podkarpackie"},
      {"podlaskie", "Podlaskie"},
      {"pomorskie", "Pomorskie"},
      {"slaskie", "Śląskie"},
      {"swietokrzyskie", "Świętokrzyskie"},
      {"warminsko-mazurskie", "Warmińsko-mazurskie"},
      {"wielkopolskie", "Wielkopolskie"},
      {"zachodniopomorskie", "Zachodniopomorskie"}
    ]
  end

  def order_type_options do
    [
      {"Delivery", "Dostawy"},
      {"Services", "Usługi"},
      {"Works", "Roboty budowlane"}
    ]
  end

  def map_order_type_to_category("Delivery"), do: "Dostawy"
  def map_order_type_to_category("Services"), do: "Usługi"
  def map_order_type_to_category("Works"), do: "Roboty budowlane"
  def map_order_type_to_category(""), do: ""
  def map_order_type_to_category(nil), do: ""

  def format_order_type("Delivery"), do: "Dostawy"
  def format_order_type("Services"), do: "Usługi"
  def format_order_type("Works"), do: "Roboty budowlane"
  def format_order_type(type), do: type || "Brak danych"

  def format_notice_type("ContractNotice"), do: "Ogłoszenie o zamówieniu"
  def format_notice_type("AgreementIntentionNotice"), do: "Ogłoszenie o zamiarze zawarcia umowy"
  def format_notice_type("TenderResultNotice"), do: "Ogłoszenie o wyniku postępowania"
  def format_notice_type("CompetitionNotice"), do: "Ogłoszenie o konkursie"
  def format_notice_type("CompetitionResultNotice"), do: "Ogłoszenie o wynikach konkursu"
  def format_notice_type("NoticeUpdateNotice"), do: "Ogłoszenie o zmianie ogłoszenia"
  def format_notice_type("AgreementUpdateNotice"), do: "Ogłoszenie o zmianie umowy"
  def format_notice_type("ContractPerformingNotice"), do: "Ogłoszenie o wykonaniu umowy"
  def format_notice_type("CircumstancesFulfillmentNotice"), do: "Ogłoszenie o spełnianiu okoliczności"
  def format_notice_type("SmallContractNotice"), do: "Ogłoszenie o zamówieniu poza Pzp"
  def format_notice_type("ConcessionNotice"), do: "Ogłoszenie o koncesji"
  def format_notice_type("ConcessionIntentionAgreementNotice"), do: "Ogłoszenie o zamiarze zawarcia umowy koncesji"
  def format_notice_type("NoticeUpdateConcession"), do: "Ogłoszenie o zmianie ogłoszenia dot. koncesji"
  def format_notice_type("ConcessionAgreementNotice"), do: "Ogłoszenie o zawarciu umowy koncesji"
  def format_notice_type("ConcessionUpdateAgreementNotice"), do: "Ogłoszenie o zmianie umowy koncesji"
  def format_notice_type(type), do: type || "Brak danych"

  # For paid users, order_type doesn't map to industries since they are different concepts
  # Industries are business sectors, order_type is procurement type
  def map_order_type_to_industry(_), do: ""

  def format_alert_name(alert, index) do
    rules = alert.rules

    # Handle both string and atom keys
    keywords = rules[:keywords] || rules["keywords"]
    tender_category = rules[:tender_category] || rules["tender_category"]
    regions = rules[:regions] || rules["regions"]
    region = rules[:region] || rules["region"]

    cond do
      # Premium user with keywords
      keywords && keywords != [] && is_list(keywords) ->
        first_keyword = List.first(keywords)
        if first_keyword && first_keyword != "", do: "Alert: #{first_keyword}", else: format_by_region(regions, index)

      # Free user with tender category
      tender_category ->
        "Alert: #{tender_category}"

      # Try to use region info
      true ->
        format_by_region(regions || region, index)
    end
  end

  defp format_by_region(nil, index), do: if(index == 1, do: "Alert główny", else: "Alert #{index}")
  defp format_by_region([], index), do: if(index == 1, do: "Alert główny", else: "Alert #{index}")

  defp format_by_region([region | _], _index) when is_binary(region) do
    region_name = region_options() |> Enum.find(fn {code, _} -> code == region end) |> elem(1)
    "Alert: #{region_name}"
  rescue
    _ -> "Alert"
  end

  defp format_by_region(region, _index) when is_binary(region) do
    region_name = region_options() |> Enum.find(fn {code, _} -> code == region end) |> elem(1)
    "Alert: #{region_name}"
  rescue
    _ -> "Alert"
  end

  defp format_by_region(_region, index), do: if(index == 1, do: "Alert główny", else: "Alert #{index}")

  def format_html_body(nil), do: ""
  def format_html_body(html) when is_binary(html) do
    # Strip potentially dangerous tags and attributes
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/is, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/is, "")
    |> String.replace(~r/on\w+\s*=\s*["'][^"']*["']/i, "")
    |> Phoenix.HTML.raw()
  end

  def format_status(:contract_signed), do: "Umowa podpisana"
  def format_status(:cancelled), do: "Anulowane"
  def format_status(_), do: "Nieznany status"
end
