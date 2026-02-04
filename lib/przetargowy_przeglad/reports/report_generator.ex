defmodule PrzetargowyPrzeglad.Reports.ReportGenerator do
  @moduledoc """
  Generates tender report content including statistics, HTML, and graphs.
  """

  alias PrzetargowyPrzeglad.Reports.GraphGenerator

  @doc """
  Generates a complete report from tender data.

  ## Options

    * `:month` - Report month (Date)
    * `:report_type` - Type of report ("detailed", "region_summary", "industry_summary", "overall")
    * `:region` - Region name (for detailed and region_summary)
    * `:order_type` - Order type (for detailed and industry_summary)
    * `:tenders` - List of TenderNotice structs

  ## Returns

  A map with all report attributes ready to be inserted into the database.
  """
  def generate(opts) do
    month = Keyword.fetch!(opts, :month)
    report_type = Keyword.fetch!(opts, :report_type)
    region = Keyword.get(opts, :region)
    order_type = Keyword.get(opts, :order_type)
    tenders = Keyword.fetch!(opts, :tenders)

    # Calculate statistics
    stats = calculate_statistics(tenders)
    trends = calculate_trends(tenders)

    # Build report data structure
    report_data = %{
      "summary" => stats.summary,
      "statistics" => stats.details,
      "trends" => trends
    }

    # Generate graphs
    graphs = GraphGenerator.generate_graphs(report_data)

    # Build metadata
    title = build_title(report_type, region, order_type, month)
    slug = build_slug(report_type, region, order_type, month)

    # Generate HTML content
    introduction_html = generate_introduction(report_type, region, order_type, month, stats)
    analysis_html = generate_analysis(report_type, region, order_type, stats, trends, graphs)
    upsell_html = generate_upsell(region, order_type)

    # Generate meta description
    meta_description = generate_meta_description(report_type, region, order_type, month, stats)

    # Get cover image
    cover_image_url = get_cover_image_url(report_type, order_type)

    %{
      title: title,
      slug: slug,
      region: region,
      order_type: order_type,
      report_month: month,
      report_type: report_type,
      report_data: report_data,
      graphs: graphs,
      introduction_html: introduction_html,
      analysis_html: analysis_html,
      upsell_html: upsell_html,
      meta_description: meta_description,
      cover_image_url: cover_image_url
    }
  end

  # Statistics Calculation

  defp calculate_statistics(tenders) do
    total_count = length(tenders)

    # Notice types that represent closed/finished tenders
    closed_notice_types = [
      "TenderResultNotice",
      "CompetitionResultNotice",
      "AgreementIntentionNotice",
      "AgreementUpdateNotice",
      "ContractPerformingNotice",
      "CircumstancesFulfillmentNotice",
      "SmallContractNotice",
      "ConcessionAgreementNotice",
      "ConcessionUpdateAgreementNotice"
    ]

    # Separate finished tenders by notice type
    finished_tenders = Enum.filter(tenders, &(&1.notice_type in closed_notice_types))
    finished_count = length(finished_tenders)

    # Calculate total contract value (only for finished tenders)
    total_contract_value =
      finished_tenders
      |> Enum.map(& &1.total_contract_value)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    # Calculate average contract value (for finished tenders)
    avg_contract_value =
      if finished_count > 0 do
        Decimal.div(total_contract_value, Decimal.new(finished_count))
      else
        Decimal.new(0)
      end

    # Calculate total estimated value (all tenders)
    total_estimated_value =
      tenders
      |> Enum.map(& &1.estimated_value)
      |> Enum.filter(&(&1 != nil))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    # Count unique contractors from both contractors and contractors_contract_details
    contractors_from_main =
      tenders
      |> Enum.flat_map(fn tender ->
        if is_list(tender.contractors) do
          Enum.map(tender.contractors, fn c ->
            cond do
              is_map(c) && Map.has_key?(c, :contractor_national_id) -> c.contractor_national_id
              is_map(c) && Map.has_key?(c, "contractor_national_id") -> c["contractor_national_id"]
              true -> nil
            end
          end)
        else
          []
        end
      end)
      |> Enum.filter(&(&1 != nil && &1 != ""))

    contractors_from_details =
      tenders
      |> Enum.flat_map(fn tender ->
        if is_list(tender.contractors_contract_details) do
          Enum.map(tender.contractors_contract_details, fn c ->
            cond do
              is_map(c) && Map.has_key?(c, :contractor_nip) -> c.contractor_nip
              is_map(c) && Map.has_key?(c, "contractor_nip") -> c["contractor_nip"]
              true -> nil
            end
          end)
        else
          []
        end
      end)
      |> Enum.filter(&(&1 != nil && &1 != ""))

    total_contractors =
      (contractors_from_main ++ contractors_from_details)
      |> Enum.uniq()
      |> length()

    # Unique organizations
    active_organizations =
      tenders
      |> Enum.map(& &1.organization_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()
      |> length()

    # Top organizations by tender count
    top_organizations =
      tenders
      |> Enum.filter(&(&1.organization_name != nil))
      |> Enum.group_by(& &1.organization_name)
      |> Enum.map(fn {name, org_tenders} -> {name, length(org_tenders)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {name, count} ->
        %{"name" => name, "count" => count}
      end)

    # Top cities by tender count
    top_cities =
      tenders
      |> Enum.filter(&(&1.organization_city != nil))
      |> Enum.group_by(& &1.organization_city)
      |> Enum.map(fn {city, city_tenders} -> {city, length(city_tenders)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {city, count} ->
        %{"city" => city, "count" => count}
      end)

    # Top tenders by contractor interest
    top_tenders =
      tenders
      |> Enum.map(fn tender ->
        contractor_count =
          if is_list(tender.contractors) do
            length(tender.contractors)
          else
            0
          end

        details_count =
          if is_list(tender.contractors_contract_details) do
            length(tender.contractors_contract_details)
          else
            0
          end

        total_interest = max(contractor_count, details_count)

        %{
          "title" => tender.order_object,
          "organization" => tender.organization_name,
          "contractor_count" => total_interest,
          "estimated_value" => tender.estimated_value
        }
      end)
      |> Enum.filter(&(&1["contractor_count"] > 0))
      |> Enum.sort_by(& &1["contractor_count"], :desc)
      |> Enum.take(10)

    # Top contractors by contract count
    contractor_data =
      Enum.flat_map(tenders, fn tender ->
        contractors = []
        # From contractors field
        contractors =
          if is_list(tender.contractors) do
            tender.contractors
            |> Enum.map(fn c ->
              name =
                cond do
                  is_map(c) && Map.has_key?(c, :contractor_name) -> c.contractor_name
                  is_map(c) && Map.has_key?(c, "contractor_name") -> c["contractor_name"]
                  true -> nil
                end

              nip =
                cond do
                  is_map(c) && Map.has_key?(c, :contractor_national_id) ->
                    c.contractor_national_id

                  is_map(c) && Map.has_key?(c, "contractor_national_id") ->
                    c["contractor_national_id"]

                  true ->
                    nil
                end

              if name && nip, do: {name, nip}
            end)
            |> Enum.filter(&(&1 != nil))
          else
            contractors
          end

        # From contractors_contract_details field
        contractors =
          if is_list(tender.contractors_contract_details) do
            details_contractors =
              tender.contractors_contract_details
              |> Enum.map(fn c ->
                name =
                  cond do
                    is_map(c) && Map.has_key?(c, :contractor_name) -> c.contractor_name
                    is_map(c) && Map.has_key?(c, "contractor_name") -> c["contractor_name"]
                    true -> nil
                  end

                nip =
                  cond do
                    is_map(c) && Map.has_key?(c, :contractor_nip) -> c.contractor_nip
                    is_map(c) && Map.has_key?(c, "contractor_nip") -> c["contractor_nip"]
                    true -> nil
                  end

                if name && nip, do: {name, nip}
              end)
              |> Enum.filter(&(&1 != nil))

            contractors ++ details_contractors
          else
            contractors
          end

        contractors
      end)

    top_contractors =
      contractor_data
      |> Enum.group_by(fn {_name, nip} -> nip end, fn {name, _nip} -> name end)
      |> Enum.map(fn {nip, names} ->
        # Take the first non-nil name
        name = List.first(names)
        {name, nip}
      end)
      |> Enum.frequencies()
      |> Enum.map(fn {{name, _nip}, count} -> {name, count} end)
      |> Enum.sort_by(fn {_name, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {name, count} ->
        %{"name" => name, "count" => count}
      end)

    # Value distribution
    by_value_range = calculate_value_distribution(tenders)

    %{
      summary: %{
        "total_tenders" => total_count,
        "closed_tenders" => finished_count,
        "total_contract_value" => Decimal.to_string(total_contract_value),
        "avg_contract_value" => Decimal.to_string(avg_contract_value),
        "total_estimated_value" => Decimal.to_string(total_estimated_value),
        "active_organizations" => active_organizations,
        "total_contractors" => total_contractors
      },
      details: %{
        "by_value_range" => by_value_range,
        "top_organizations" => top_organizations,
        "top_cities" => top_cities,
        "top_contractors" => top_contractors,
        "top_tenders" => top_tenders
      }
    }
  end

  defp calculate_value_distribution(tenders) do
    value_ranges = [
      {"< 100k PLN", 0, 100_000},
      {"100k - 500k PLN", 100_000, 500_000},
      {"500k - 1M PLN", 500_000, 1_000_000},
      {"1M - 5M PLN", 1_000_000, 5_000_000},
      {"> 5M PLN", 5_000_000, :infinity}
    ]

    Enum.map(value_ranges, fn {label, min, max} ->
      count = count_in_range(tenders, min, max)
      %{"label" => label, "count" => count}
    end)
  end

  defp count_in_range(tenders, min, :infinity) do
    Enum.count(tenders, fn t ->
      t.estimated_value != nil &&
        Decimal.compare(t.estimated_value, Decimal.new(min)) in [:gt, :eq]
    end)
  end

  defp count_in_range(tenders, min, max) do
    Enum.count(tenders, fn t ->
      t.estimated_value != nil &&
        Decimal.compare(t.estimated_value, Decimal.new(min)) in [:gt, :eq] &&
        Decimal.compare(t.estimated_value, Decimal.new(max)) == :lt
    end)
  end

  defp calculate_trends(tenders) do
    # Group by week and count
    weekly_counts =
      tenders
      |> Enum.group_by(fn t ->
        date = DateTime.to_date(t.publication_date)
        {iso_year, iso_week} = get_iso_week(date)
        {iso_year, iso_week}
      end)
      |> Enum.map(fn {{year, week}, week_tenders} ->
        %{"year" => year, "week" => week, "count" => length(week_tenders)}
      end)
      |> Enum.sort_by(fn %{"year" => y, "week" => w} -> {y, w} end)

    %{"weekly_counts" => weekly_counts}
  end

  # Calculate week number for a date (simple week of year)
  defp get_iso_week(date) do
    days_since_year_start = Date.diff(date, Date.new!(date.year, 1, 1))
    week_number = div(days_since_year_start, 7) + 1
    {date.year, week_number}
  end

  # Title and Slug Generation

  defp build_title("detailed", region, order_type, month) do
    region_name = format_region_name(region)
    category = format_order_type(order_type)
    month_name = format_month(month)

    "#{category} w regionie #{region_name} - #{month_name}"
  end

  defp build_title("region_summary", region, _order_type, month) do
    region_name = format_region_name(region)
    month_name = format_month(month)

    "Region #{region_name} - #{month_name}"
  end

  defp build_title("industry_summary", _region, order_type, month) do
    category = format_order_type(order_type)
    month_name = format_month(month)

    "#{category} - #{month_name}"
  end

  defp build_title("overall", _region, _order_type, month) do
    month_name = format_month(month)

    "Zamówienia publiczne - #{month_name}"
  end

  defp build_slug("detailed", region, order_type, month) do
    month_str = Date.to_iso8601(month)
    "#{region}-#{String.downcase(order_type)}-#{month_str}"
  end

  defp build_slug("region_summary", region, _order_type, month) do
    month_str = Date.to_iso8601(month)
    "region-#{region}-#{month_str}"
  end

  defp build_slug("industry_summary", _region, order_type, month) do
    month_str = Date.to_iso8601(month)
    "industry-#{String.downcase(order_type)}-#{month_str}"
  end

  defp build_slug("overall", _region, _order_type, month) do
    month_str = Date.to_iso8601(month)
    "overall-#{month_str}"
  end

  # HTML Content Generation

  defp generate_introduction("detailed", region, order_type, month, stats) do
    region_name = format_region_name(region)
    category = format_order_type(order_type)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    """
    <p>W miesiącu <strong>#{month_name}</strong> w regionie <strong>#{region_name}</strong>
    opublikowano <strong>#{total} przetargów</strong> z kategorii <strong>#{category}</strong>.</p>

    <p>Niniejszy raport przedstawia szczegółową analizę ogłoszeń o zamówieniach publicznych,
    wartości kontraktów oraz aktywności zamawiających w tym okresie.</p>
    """
  end

  defp generate_introduction("region_summary", region, _order_type, month, stats) do
    region_name = format_region_name(region)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    """
    <p>W miesiącu <strong>#{month_name}</strong> w regionie <strong>#{region_name}</strong>
    opublikowano łącznie <strong>#{total} przetargów</strong> we wszystkich kategoriach.</p>

    <p>Niniejszy raport przedstawia kompleksową analizę rynku zamówień publicznych
    w regionie, obejmującą wszystkie typy przetargów.</p>
    """
  end

  defp generate_introduction("industry_summary", _region, order_type, month, stats) do
    category = format_order_type(order_type)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    """
    <p>W miesiącu <strong>#{month_name}</strong> opublikowano łącznie <strong>#{total} przetargów</strong>
    z kategorii <strong>#{category}</strong> we wszystkich regionach Polski.</p>

    <p>Raport przedstawia ogólnopolską analizę zamówień publicznych w tej kategorii.</p>
    """
  end

  defp generate_introduction("overall", _region, _order_type, month, stats) do
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    """
    <p>W miesiącu <strong>#{month_name}</strong> opublikowano łącznie <strong>#{total} przetargów</strong>
    we wszystkich kategoriach i regionach Polski.</p>

    <p>Raport przedstawia kompleksowy przegląd rynku zamówień publicznych w całej Polsce.</p>
    """
  end

  defp generate_analysis(_report_type, _region, _order_type, stats, _trends, graphs) do
    closed_count = stats.summary["closed_tenders"]
    total_contract_value = stats.summary["total_contract_value"] |> Decimal.new() |> format_currency()
    avg_contract_value = stats.summary["avg_contract_value"] |> Decimal.new() |> format_currency()
    total_estimated_value = stats.summary["total_estimated_value"] |> Decimal.new() |> format_currency()
    total_contractors = stats.summary["total_contractors"]

    top_org_html =
      if length(stats.details["top_organizations"]) > 0 do
        orgs_list =
          stats.details["top_organizations"]
          |> Enum.take(10)
          |> Enum.with_index(1)
          |> Enum.map_join("\n", fn {org, index} ->
            "<li><strong>#{index}. #{org["name"]}</strong> - #{org["count"]} ogłoszeń</li>"
          end)

        """
        <p>W analizowanym okresie przetargi ogłosiło łącznie <strong>#{stats.summary["active_organizations"]} jednostek zamawiających</strong>.
        Poniżej przedstawiamy najbardziej aktywnych zamawiających:</p>
        <ol class="top-contractors-list">
        #{orgs_list}
        </ol>
        """
      else
        ""
      end

    top_cities_html =
      if length(stats.details["top_cities"]) > 0 do
        cities_list =
          stats.details["top_cities"]
          |> Enum.take(5)
          |> Enum.with_index(1)
          |> Enum.map_join("\n", fn {city, index} ->
            "<li><strong>#{index}. #{city["city"]}</strong> - #{city["count"]} ogłoszeń</li>"
          end)

        """
        <p>Najwięcej przetargów opublikowano w następujących miastach:</p>
        <ol class="top-contractors-list">
        #{cities_list}
        </ol>
        """
      else
        ""
      end

    top_contractors_html =
      if length(stats.details["top_contractors"]) > 0 do
        contractors_list =
          stats.details["top_contractors"]
          |> Enum.take(10)
          |> Enum.with_index(1)
          |> Enum.map_join("\n", fn {contractor, index} ->
            "<li><strong>#{index}. #{contractor["name"]}</strong> - #{contractor["count"]} kontraktów</li>"
          end)

        """
        <p>Najbardziej aktywni wykonawcy w analizowanym okresie:</p>
        <ol class="top-contractors-list">
        #{contractors_list}
        </ol>
        """
      else
        ""
      end

    """
    <h3>Trendy publikacji</h3>
    <p>Wykres poniżej przedstawia tygodniowy rozkład publikacji przetargów w analizowanym miesiącu.
    Analiza dynamiki ogłoszeń pozwala zidentyfikować okresy największej aktywności zamawiających
    oraz pomaga w planowaniu działań związanych z monitorowaniem rynku zamówień publicznych.</p>
    <div class="graph-container">
    #{graphs["tender_count_trend"] || ""}
    </div>

    <h3>Przetargi rozstrzygnięte</h3>
    <p>W analizowanym okresie <strong>rozstrzygnięto #{closed_count} przetargów</strong>
    o łącznej wartości kontraktowej <strong>#{total_contract_value}</strong>.
    Średnia wartość rozstrzygniętego kontraktu wyniosła <strong>#{avg_contract_value}</strong>.</p>

    <p>Łączna szacowana wartość wszystkich ogłoszonych przetargów wyniosła <strong>#{total_estimated_value}</strong>.</p>

    <h3>Aktywność wykonawców</h3>
    <p>W przetargach wzięło udział łącznie <strong>#{total_contractors} unikalnych wykonawców</strong>,
    co świadczy o dużym zainteresowaniu rynkiem zamówień publicznych.</p>
    #{top_contractors_html}

    <h3>Przetargi o największym zainteresowaniu</h3>
    <p>Poniższe przetargi wzbudziły największe zainteresowanie wśród wykonawców,
    mierzone liczbą złożonych ofert:</p>
    <ol class="top-contractors-list">
    #{Enum.map_join(stats.details["top_tenders"], "\n", fn tender ->
      value_info = if tender["estimated_value"] do
        " - szacowana wartość: #{tender["estimated_value"] |> Decimal.new() |> format_currency()}"
      else
        ""
      end

      "<li><strong>#{String.slice(tender["title"], 0..100)}</strong><br/>
      Zamawiający: #{tender["organization"]}<br/>
      Liczba ofert: #{tender["contractor_count"]}#{value_info}</li>"
    end)}
    </ol>

    <h3>Aktywność zamawiających</h3>
    #{top_org_html}

    <h3>Rozkład geograficzny</h3>
    #{top_cities_html}

    <h3>Rozkład wartości przetargów</h3>
    <p>Poniższy wykres przedstawia rozkład ogłoszonych przetargów według przedziałów wartości szacunkowej.
    Analiza pokazuje, w jakich segmentach wartościowych koncentruje się największa aktywność zamawiających
    oraz pozwala zidentyfikować dominujące kategorie zamówień pod względem ich wartości.</p>
    <div class="graph-container">
    #{graphs["value_distribution"] || ""}
    </div>
    """
  end

  defp generate_upsell(_region, _order_type) do
    """
    <div class="upsell-content">
      <h3>Nie przegap żadnego przetargu!</h3>
      <p>Z naszą platformą <strong>Przetargowy Przegląd</strong> możesz:</p>
      <ul>
        <li>Otrzymywać <strong>automatyczne powiadomienia</strong> o nowych przetargach</li>
        <li>Filtrować ogłoszenia według <strong>regionu, branży i słów kluczowych</strong></li>
        <li>Monitorować <strong>konkurencję</strong> i aktywność zamawiających</li>
        <li>Przeglądać <strong>historyczne dane</strong> i analizy rynkowe</li>
      </ul>
      <p class="cta">
        <a href="/register/premium" class="cta-button">Dołącz do Premium →</a>
      </p>
    </div>
    """
  end

  defp generate_meta_description("detailed", region, order_type, month, stats) do
    region_name = format_region_name(region)
    category = format_order_type(order_type)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    String.slice(
      "Raport przetargów publicznych: #{category} w regionie #{region_name} za #{month_name}. Analiza #{total} ogłoszeń, statystyki wartości i aktywności zamawiających.",
      0..159
    )
  end

  defp generate_meta_description("region_summary", region, _order_type, month, stats) do
    region_name = format_region_name(region)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    String.slice(
      "Raport przetargów publicznych: region #{region_name} za #{month_name}. Analiza #{total} ogłoszeń we wszystkich kategoriach.",
      0..159
    )
  end

  defp generate_meta_description("industry_summary", _region, order_type, month, stats) do
    category = format_order_type(order_type)
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    String.slice(
      "Raport przetargów publicznych: #{category} za #{month_name}. Ogólnopolska analiza #{total} ogłoszeń.",
      0..159
    )
  end

  defp generate_meta_description("overall", _region, _order_type, month, stats) do
    month_name = format_month(month)
    total = stats.summary["total_tenders"]

    String.slice(
      "Raport przetargów publicznych za #{month_name}. Kompleksowa analiza #{total} ogłoszeń z całej Polski.",
      0..159
    )
  end

  defp get_cover_image_url("detailed", order_type), do: get_order_type_image(order_type)
  defp get_cover_image_url("industry_summary", order_type), do: get_order_type_image(order_type)
  defp get_cover_image_url(_report_type, _order_type), do: "/images/reports/summary.svg"

  defp get_order_type_image("Delivery"), do: "/images/reports/delivery.svg"
  defp get_order_type_image("Services"), do: "/images/reports/services.svg"
  defp get_order_type_image("Works"), do: "/images/reports/works.svg"
  defp get_order_type_image(_), do: "/images/reports/default.svg"

  # Helper Formatters

  defp format_region_name(nil), do: "Polska"

  defp format_region_name(region) do
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

    Map.get(region_map, region, region)
  end

  defp format_order_type("Delivery"), do: "Dostawy"
  defp format_order_type("Services"), do: "Usługi"
  defp format_order_type("Works"), do: "Roboty budowlane"
  defp format_order_type(nil), do: "Wszystkie kategorie"
  defp format_order_type(other), do: other

  defp format_month(date) do
    months = [
      "styczeń",
      "luty",
      "marzec",
      "kwiecień",
      "maj",
      "czerwiec",
      "lipiec",
      "sierpień",
      "wrzesień",
      "październik",
      "listopad",
      "grudzień"
    ]

    month_name = Enum.at(months, date.month - 1)
    "#{month_name} #{date.year}"
  end

  defp format_currency(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1 ")
    |> Kernel.<>(" PLN")
  end
end
