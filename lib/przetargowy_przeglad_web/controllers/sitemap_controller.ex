defmodule PrzetargowyPrzegladWeb.SitemapController do
  use PrzetargowyPrzegladWeb, :controller
  use PrzetargowyPrzegladWeb, :verified_routes

  import Ecto.Query

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Reports.TenderReport
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  def index(conn, _params) do
    base_url = "https://#{conn.host}"

    static_urls = [
      # Static pages
      %{loc: "#{base_url}/", changefreq: "daily", priority: "1.0"},
      %{loc: "#{base_url}/tenders", changefreq: "hourly", priority: "0.9"},
      %{loc: "#{base_url}/reports", changefreq: "weekly", priority: "0.9"},

      # Regional tender pages - all 16 voivodeships
      %{loc: "#{base_url}/przetargi/dolnoslaskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/kujawsko-pomorskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/lubelskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/lubuskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/lodzkie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/malopolskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/mazowieckie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/opolskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/podkarpackie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/podlaskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/pomorskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/slaskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/swietokrzyskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/warminsko-mazurskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/wielkopolskie", changefreq: "daily", priority: "0.8"},
      %{loc: "#{base_url}/przetargi/zachodniopomorskie", changefreq: "daily", priority: "0.8"},

      # Regional report pages
      %{loc: "#{base_url}/raporty/dolnoslaskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/kujawsko-pomorskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/lubelskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/lubuskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/lodzkie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/malopolskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/mazowieckie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/opolskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/podkarpackie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/podlaskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/pomorskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/slaskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/swietokrzyskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/warminsko-mazurskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/wielkopolskie", changefreq: "monthly", priority: "0.7"},
      %{loc: "#{base_url}/raporty/zachodniopomorskie", changefreq: "monthly", priority: "0.7"}
    ]

    # Get active tenders (non-expired, ContractNotice type only)
    active_tenders = get_active_tenders()

    tender_urls =
      Enum.map(active_tenders, fn tender ->
        # Use Phoenix's url helper for proper encoding
        tender_url = url(~p"/tenders/#{tender.object_id}")

        %{
          loc: tender_url,
          changefreq: "daily",
          priority: "0.8",
          lastmod: format_lastmod(tender.updated_at || tender.inserted_at)
        }
      end)

    # Get all reports
    reports = get_reports()

    report_urls =
      Enum.map(reports, fn report ->
        report_url = url(~p"/reports/#{report.slug}")

        %{
          loc: report_url,
          changefreq: "monthly",
          priority: "0.7",
          lastmod: format_lastmod(report.updated_at || report.inserted_at)
        }
      end)

    urls = static_urls ++ tender_urls ++ report_urls

    xml = generate_sitemap_xml(urls)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp get_active_tenders do
    now = DateTime.utc_now()

    Repo.all(
      from(t in TenderNotice,
        where: t.notice_type == "ContractNotice",
        where: t.submitting_offers_date > ^now,
        order_by: [desc: t.publication_date],
        limit: 1000,
        select: %{object_id: t.object_id, inserted_at: t.inserted_at, updated_at: t.updated_at}
      )
    )
  end

  defp get_reports do
    Repo.all(
      from(r in TenderReport,
        order_by: [desc: r.report_month],
        select: %{slug: r.slug, inserted_at: r.inserted_at, updated_at: r.updated_at}
      )
    )
  end

  defp format_lastmod(nil), do: nil

  defp format_lastmod(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> Kernel.<>("+00:00")
  end

  defp format_lastmod(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp generate_sitemap_xml(urls) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_to_xml/1)}
    </urlset>
    """
  end

  defp url_to_xml(url) do
    lastmod_tag =
      if Map.has_key?(url, :lastmod) && url.lastmod do
        "<lastmod>#{url.lastmod}</lastmod>\n        "
      else
        ""
      end

    """
      <url>
        <loc>#{url.loc}</loc>
        #{lastmod_tag}<changefreq>#{url.changefreq}</changefreq>
        <priority>#{url.priority}</priority>
      </url>
    """
  end
end
