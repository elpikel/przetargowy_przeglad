defmodule PrzetargowyPrzegladWeb.PageControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Przetargowy Przegląd"
  end
end
