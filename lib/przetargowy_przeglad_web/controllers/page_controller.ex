defmodule PrzetargowyPrzegladWeb.PageController do
  use PrzetargowyPrzegladWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:home)
  end
end
