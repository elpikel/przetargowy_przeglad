defmodule PrzetargowyPrzegladWeb.TenderController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Tenders

  plug :put_layout, false
  plug :put_root_layout, false
  plug PrzetargowyPrzegladWeb.Plugs.OptionalAuth

  def index(conn, params) do
    page = parse_page(params["page"])
    current_user = conn.assigns[:current_user]

    regions = params["regions"] || []
    order_types = params["order_types"] || []

    search_opts = [
      query: params["q"],
      regions: regions,
      order_types: order_types,
      page: page,
      per_page: 20
    ]

    result = Tenders.search_tender_notices(search_opts)

    # Load user alerts if logged in
    user_alerts =
      if current_user do
        PrzetargowyPrzeglad.Accounts.list_user_alerts(current_user)
      else
        []
      end

    # SEO meta tags
    page_title = build_page_title(params, page, result.total_count)
    page_description = build_page_description(params, result.total_count)

    # Structured data for search results
    structured_data =
      if result.total_count > 0 do
        build_breadcrumb_data(params)
      end

    conn
    |> assign(:page_title, page_title)
    |> assign(:page_description, page_description)
    |> assign(:canonical_url, build_canonical_url(conn, params))
    |> assign(:structured_data, structured_data)
    |> render(:index,
      notices: result.notices,
      total_count: result.total_count,
      page: result.page,
      total_pages: result.total_pages,
      query: params["q"] || "",
      regions: regions,
      order_types: order_types,
      current_user: current_user,
      user_alerts: user_alerts
    )
  end

  def show(conn, %{"id" => id}) do
    case Tenders.get_tender_notice(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: PrzetargowyPrzegladWeb.ErrorHTML)
        |> render(:"404")

      tender ->
        # Check if tender is expired
        is_expired = tender.submitting_offers_date && DateTime.compare(tender.submitting_offers_date, DateTime.utc_now()) == :lt

        # SEO meta tags
        page_title = build_tender_page_title(tender)
        page_description = build_tender_page_description(tender)
        canonical_url = url(~p"/tenders/#{tender.object_id}")

        # Structured data
        structured_data = [
          PrzetargowyPrzegladWeb.SEO.structured_data_tender(tender),
          build_tender_breadcrumb_data(tender)
        ]

        conn
        |> assign(:page_title, page_title)
        |> assign(:page_description, page_description)
        |> assign(:canonical_url, canonical_url)
        |> assign(:structured_data, structured_data)
        |> assign(:noindex, is_expired)
        |> render(:show, tender: tender, is_expired: is_expired)
    end
  end

  defp build_page_title(params, page, total_count) do
    query = params["q"]
    regions = params["regions"] || []
    page_suffix = if page > 1, do: " - Strona #{page}", else: ""

    cond do
      query && query != "" ->
        "#{query} - Wyniki wyszukiwania przetargów#{page_suffix} | Przetargowy Przegląd"

      regions != [] && length(regions) == 1 ->
        region_name = get_region_name(List.first(regions))
        "Przetargi w regionie #{region_name}#{page_suffix} | Przetargowy Przegląd"

      total_count > 0 ->
        "Aktualne przetargi publiczne#{page_suffix} | Przetargowy Przegląd"

      true ->
        "Wyszukaj przetargi publiczne | Przetargowy Przegląd"
    end
  end

  defp build_page_description(params, total_count) do
    query = params["q"]
    regions = params["regions"] || []

    cond do
      query && query != "" ->
        "Znaleziono #{total_count} przetargów dla zapytania '#{query}'. Przeglądaj aktualne ogłoszenia o zamówieniach publicznych z całej Polski."

      regions != [] && length(regions) == 1 ->
        region_name = get_region_name(List.first(regions))

        "Przeglądaj #{total_count} aktualnych przetargów publicznych w regionie #{region_name}. Znajdź zamówienia publiczne dopasowane do Twojej branży."

      total_count > 0 ->
        "Przeglądaj #{total_count} aktualnych ogłoszeń o przetargach publicznych z całej Polski. Baza zamówień publicznych aktualizowana codziennie."

      true ->
        "Wyszukaj i monitoruj przetargi publiczne z całej Polski. Otrzymuj powiadomienia o nowych ogłoszeniach dopasowanych do Twojej branży i regionu."
    end
  end

  defp build_canonical_url(conn, params) do
    base_url = "https://#{conn.host}/tenders"

    # Only include meaningful params in canonical URL
    query_params =
      []
      |> maybe_add_param("q", params["q"])
      |> maybe_add_array_params("regions[]", params["regions"])
      |> maybe_add_array_params("order_types[]", params["order_types"])
      |> maybe_add_param("page", params["page"])

    if query_params == "" do
      base_url
    else
      "#{base_url}?#{query_params}"
    end
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, _key, ""), do: params
  defp maybe_add_param(params, _key, "1"), do: params

  defp maybe_add_param(params, key, value) do
    param_string = URI.encode_query([{key, value}])
    if params == "", do: param_string, else: "#{params}&#{param_string}"
  end

  defp maybe_add_array_params(params, _key, nil), do: params
  defp maybe_add_array_params(params, _key, []), do: params

  defp maybe_add_array_params(params, key, values) when is_list(values) do
    param_string = Enum.map_join(values, "&", fn v -> "#{key}=#{URI.encode_www_form(v)}" end)
    if params == "", do: param_string, else: "#{params}&#{param_string}"
  end

  defp get_region_name(region_code) do
    region_map = %{
      "dolnoslaskie" => "Dolnośląskie",
      "kujawsko-pomorskie" => "Kujawsko-pomorskie",
      "lubelskie" => "Lubelskie",
      "lubuskie" => "Lubuskie",
      "lodzkie" => "Łódzkie",
      "malopolskie" => "Małopolskie",
      "mazowieckie" => "Mazowieckie",
      "opolskie" => "Opolskie",
      "podkarpackie" => "Podkarpackie",
      "podlaskie" => "Podlaskie",
      "pomorskie" => "Pomorskie",
      "slaskie" => "Śląskie",
      "swietokrzyskie" => "Świętokrzyskie",
      "warminsko-mazurskie" => "Warmińsko-mazurskie",
      "wielkopolskie" => "Wielkopolskie",
      "zachodniopomorskie" => "Zachodniopomorskie"
    }

    Map.get(region_map, region_code, region_code)
  end

  defp build_breadcrumb_data(params) do
    query = params["q"]
    regions = params["regions"] || []

    items = [{"Strona główna", "https://przetargowyprzeglad.pl/"}]

    items = items ++ [{"Przetargi", "https://przetargowyprzeglad.pl/tenders"}]

    items =
      cond do
        query && query != "" ->
          items ++ [{"Wyniki dla: #{query}", "https://przetargowyprzeglad.pl/tenders?q=#{URI.encode_www_form(query)}"}]

        regions != [] && length(regions) == 1 ->
          region_name = get_region_name(List.first(regions))
          items ++ [{"Region: #{region_name}", "https://przetargowyprzeglad.pl/tenders?regions[]=#{List.first(regions)}"}]

        true ->
          items
      end

    PrzetargowyPrzegladWeb.SEO.structured_data_breadcrumb(items)
  end

  defp build_tender_page_title(tender) do
    "#{tender.order_object} - #{tender.organization_name} | Przetargowy Przegląd"
  end

  defp build_tender_page_description(tender) do
    deadline = if tender.submitting_offers_date do
      Calendar.strftime(tender.submitting_offers_date, "%d.%m.%Y")
    else
      "brak terminu"
    end

    "Przetarg: #{tender.order_object}. Zamawiający: #{tender.organization_name}, #{tender.organization_city}. " <>
    "Numer BZP: #{tender.bzp_number}. Termin składania ofert: #{deadline}."
  end

  defp build_tender_breadcrumb_data(tender) do
    region_code = get_province_region_code(tender.organization_province)
    region_name = get_region_name(region_code)

    items = [
      {"Strona główna", url(~p"/")},
      {"Przetargi", url(~p"/tenders")},
      {"#{region_name}", url(~p"/tenders?#{[regions: [region_code]]}")},
      {String.slice(tender.order_object, 0..50), url(~p"/tenders/#{tender.object_id}")}
    ]

    PrzetargowyPrzegladWeb.SEO.structured_data_breadcrumb(items)
  end

  defp get_province_region_code(province_code) do
    province_to_region = %{
      "PL02" => "dolnoslaskie",
      "PL04" => "kujawsko-pomorskie",
      "PL06" => "lubelskie",
      "PL08" => "lubuskie",
      "PL10" => "lodzkie",
      "PL12" => "malopolskie",
      "PL14" => "mazowieckie",
      "PL16" => "opolskie",
      "PL18" => "podkarpackie",
      "PL20" => "podlaskie",
      "PL22" => "pomorskie",
      "PL24" => "slaskie",
      "PL26" => "swietokrzyskie",
      "PL28" => "warminsko-mazurskie",
      "PL30" => "wielkopolskie",
      "PL32" => "zachodniopomorskie"
    }

    Map.get(province_to_region, province_code, "mazowieckie")
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_page(_), do: 1
end
