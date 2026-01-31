defmodule PrzetargowyPrzegladWeb.PageController do
  use PrzetargowyPrzegladWeb, :controller

  plug :put_layout, false
  plug :put_root_layout, false
  plug PrzetargowyPrzegladWeb.Plugs.OptionalAuth

  def home(conn, _params) do
    render(conn, :home, current_user: conn.assigns[:current_user])
  end

  def rules(conn, _params) do
    render(conn, :rules)
  end

  def privacy_policy(conn, _params) do
    render(conn, :privacy_policy)
  end
end
