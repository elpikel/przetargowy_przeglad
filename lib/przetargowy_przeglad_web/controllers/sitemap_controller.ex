defmodule PrzetargowyPrzegladWeb.SitemapController do
  use PrzetargowyPrzegladWeb, :controller

  def index(conn, _params) do
    base_url = "https://#{conn.host}"

    urls = [
      # Static pages
      %{loc: "#{base_url}/", changefreq: "daily", priority: "1.0"},
      %{loc: "#{base_url}/tenders", changefreq: "hourly", priority: "0.9"},
      %{loc: "#{base_url}/pricing", changefreq: "weekly", priority: "0.8"},

      # Common search pages
      %{loc: "#{base_url}/tenders?regions[]=mazowieckie", changefreq: "daily", priority: "0.7"},
      %{loc: "#{base_url}/tenders?regions[]=malopolskie", changefreq: "daily", priority: "0.7"},
      %{loc: "#{base_url}/tenders?regions[]=wielkopolskie", changefreq: "daily", priority: "0.7"},
      %{loc: "#{base_url}/tenders?order_types[]=Delivery", changefreq: "daily", priority: "0.7"},
      %{loc: "#{base_url}/tenders?order_types[]=Services", changefreq: "daily", priority: "0.7"},
      %{loc: "#{base_url}/tenders?order_types[]=Works", changefreq: "daily", priority: "0.7"}
    ]

    xml = generate_sitemap_xml(urls)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
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
    """
      <url>
        <loc>#{url.loc}</loc>
        <changefreq>#{url.changefreq}</changefreq>
        <priority>#{url.priority}</priority>
      </url>
    """
  end
end
