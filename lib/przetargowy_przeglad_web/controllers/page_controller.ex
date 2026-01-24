defmodule PrzetargowyPrzegladWeb.PageController do
  use PrzetargowyPrzegladWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
