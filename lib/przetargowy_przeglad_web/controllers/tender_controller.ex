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
    user_alerts = if current_user do
      PrzetargowyPrzeglad.Accounts.list_user_alerts(current_user)
    else
      []
    end

    render(conn, :index,
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

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end
  defp parse_page(_), do: 1
end
