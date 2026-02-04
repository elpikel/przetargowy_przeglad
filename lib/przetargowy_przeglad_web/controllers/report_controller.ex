defmodule PrzetargowyPrzegladWeb.ReportController do
  @moduledoc """
  Controller for displaying tender reports.
  """
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Reports

  plug :put_layout, false
  plug :put_root_layout, false
  plug PrzetargowyPrzegladWeb.Plugs.OptionalAuth

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
