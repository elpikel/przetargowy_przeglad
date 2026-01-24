defmodule PrzetargowyPrzegladWeb.PageController do
  use PrzetargowyPrzegladWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:home)
  end

  def rules(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:rules)
  end

  def privacy_policy(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:privacy_policy)
  end
end
