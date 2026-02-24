defmodule PrzetargowyPrzegladWeb.ReportController do
  @moduledoc """
  Controller for displaying tender reports.
  """
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Reports

  plug :put_layout, false
  plug :put_root_layout, false
  plug PrzetargowyPrzegladWeb.Plugs.OptionalAuth

  @valid_regions ~w(dolnoslaskie kujawsko-pomorskie lubelskie lubuskie lodzkie malopolskie mazowieckie opolskie podkarpackie podlaskie pomorskie slaskie swietokrzyskie warminsko-mazurskie wielkopolskie zachodniopomorskie)

  def index(conn, params) do
    page = parse_page(params["page"])

    search_opts = [
      page: page,
      per_page: 12
    ]

    result = Reports.list_tender_reports(search_opts)

    # SEO
    page_title = build_page_title(page)

    page_description =
      "Comiesięczne raporty analityczne przetargów publicznych z całej Polski. " <>
        "Statystyki, trendy i analiza rynku zamówień publicznych."

    canonical_url = build_canonical_url(conn, page)

    conn
    |> assign(:page_title, page_title)
    |> assign(:page_description, page_description)
    |> assign(:canonical_url, canonical_url)
    |> assign(:og_image, url(~p"/images/reports/summary.svg"))
    |> assign(:og_type, "website")
    |> assign(:keywords, "raporty przetargów, zamówienia publiczne, analiza przetargów, statystyki przetargów")
    |> render(:index,
      reports: result.reports,
      total_count: result.total_count,
      page: result.page,
      total_pages: result.total_pages
    )
  end

  def show(conn, %{"slug" => slug}) do
    case Reports.get_report_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: PrzetargowyPrzegladWeb.ErrorHTML)
        |> render(:"404")

      report ->
        page_title = "#{report.title} | Przetargowy Przegląd"
        canonical_url = build_canonical_url(conn, report.slug)

        # Build keywords from report data
        keywords =
          [
            "raport przetargów",
            report.region && PrzetargowyPrzegladWeb.ReportHTML.format_region_name(report.region),
            report.order_type &&
              PrzetargowyPrzegladWeb.ReportHTML.format_order_type(report.order_type),
            "zamówienia publiczne",
            "#{report.report_month.year}",
            PrzetargowyPrzegladWeb.ReportHTML.format_report_date(report.report_month)
          ]
          |> Enum.filter(& &1)
          |> Enum.join(", ")

        # Structured data for SEO
        structured_data = build_structured_data(report, canonical_url)

        # Build full URL for cover image
        og_image_url =
          ~p"/"
          |> url()
          |> URI.parse()
          |> Map.put(:path, report.cover_image_url)
          |> URI.to_string()

        conn
        |> assign(:page_title, page_title)
        |> assign(:page_description, report.meta_description)
        |> assign(:canonical_url, canonical_url)
        |> assign(:og_image, og_image_url)
        |> assign(:og_type, "article")
        |> assign(:keywords, keywords)
        |> assign(:structured_data, structured_data)
        |> render(:show, report: report)
    end
  end

  @doc """
  Regional reports landing page with SEO-friendly clean URL.
  /raporty/:region -> renders reports filtered by region
  """
  def region(conn, %{"region" => region} = params) do
    if region in @valid_regions do
      page = parse_page(params["page"])

      search_opts = [
        page: page,
        per_page: 12
      ]

      result = Reports.list_tender_reports_by_region(region, search_opts)

      region_name = PrzetargowyPrzegladWeb.ReportHTML.format_region_name(region)
      page_suffix = if page > 1, do: " - Strona #{page}", else: ""

      page_title = "Raporty przetargów #{region_name}#{page_suffix} | Przetargowy Przegląd"

      page_description =
        "Comiesięczne raporty analityczne przetargów publicznych w województwie #{region_name}. " <>
          "Statystyki, trendy i analiza rynku zamówień publicznych w regionie."

      canonical_url = build_region_canonical_url(conn, region, params)

      structured_data = build_region_breadcrumb_data(region, region_name)

      conn
      |> assign(:page_title, page_title)
      |> assign(:page_description, page_description)
      |> assign(:canonical_url, canonical_url)
      |> assign(:og_image, url(~p"/images/reports/summary.svg"))
      |> assign(:og_type, "website")
      |> assign(:keywords, "raporty przetargów #{region_name}, zamówienia publiczne #{region_name}, analiza przetargów #{region_name}")
      |> assign(:structured_data, structured_data)
      |> assign(:region, region)
      |> assign(:region_name, region_name)
      |> render(:index,
        reports: result.reports,
        total_count: result.total_count,
        page: result.page,
        total_pages: result.total_pages
      )
    else
      conn
      |> put_status(:not_found)
      |> put_view(html: PrzetargowyPrzegladWeb.ErrorHTML)
      |> render(:"404")
    end
  end

  defp build_region_canonical_url(conn, region, params) do
    base_url = "https://#{conn.host}/raporty/#{region}"

    page = params["page"]

    if page && page != "1" do
      "#{base_url}?page=#{page}"
    else
      base_url
    end
  end

  defp build_region_breadcrumb_data(region, region_name) do
    items = [
      {"Strona główna", "https://przetargowyprzeglad.pl/"},
      {"Raporty", "https://przetargowyprzeglad.pl/reports"},
      {"Raporty #{region_name}", "https://przetargowyprzeglad.pl/raporty/#{region}"}
    ]

    PrzetargowyPrzegladWeb.SEO.structured_data_breadcrumb(items)
  end

  # Private Functions

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp build_page_title(1), do: "Raporty przetargów publicznych | Przetargowy Przegląd"

  defp build_page_title(page), do: "Raporty przetargów - Strona #{page} | Przetargowy Przegląd"

  defp build_canonical_url(_conn, 1) do
    url(~p"/reports")
  end

  defp build_canonical_url(_conn, page) when is_integer(page) do
    url(~p"/reports?page=#{page}")
  end

  defp build_canonical_url(_conn, slug) when is_binary(slug) do
    url(~p"/reports/#{slug}")
  end

  defp build_structured_data(report, canonical_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Report",
      "headline" => report.title,
      "description" => report.meta_description,
      "datePublished" => report.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      "dateModified" => report.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
      "author" => %{
        "@type" => "Organization",
        "name" => "Przetargowy Przegląd",
        "url" => url(~p"/")
      },
      "publisher" => %{
        "@type" => "Organization",
        "name" => "Przetargowy Przegląd",
        "url" => url(~p"/")
      },
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => canonical_url
      },
      "image" =>
        ~p"/"
        |> url()
        |> URI.parse()
        |> Map.put(:path, report.cover_image_url)
        |> URI.to_string(),
      "about" => %{
        "@type" => "Thing",
        "name" => "Zamówienia publiczne w Polsce"
      },
      "keywords" =>
        [
          report.region,
          report.order_type,
          "przetargi publiczne",
          "zamówienia publiczne"
        ]
        |> Enum.filter(& &1)
        |> Enum.join(", ")
    }
  end
end
