defmodule PrzetargowyPrzegladWeb.TenderController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Tenders

  plug :put_layout, false
  plug :put_root_layout, false

  def index(conn, params) do
    page = parse_page(params["page"])

    search_opts = [
      query: params["q"],
      region: params["region"],
      order_type: params["order_type"],
      page: page,
      per_page: 20
    ]

    result = Tenders.search_tender_notices(search_opts)

    render(conn, :index,
      notices: result.notices,
      total_count: result.total_count,
      page: result.page,
      total_pages: result.total_pages,
      query: params["q"] || "",
      region: params["region"] || "",
      order_type: params["order_type"] || ""
    )
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
