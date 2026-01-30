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

  def build_url(query, region, order_type, page) do
    params =
      [q: query, region: region, order_type: order_type, page: page]
      |> Enum.filter(fn {_k, v} -> v && v != "" end)
      |> URI.encode_query()

    "/tenders?#{params}"
  end
end
