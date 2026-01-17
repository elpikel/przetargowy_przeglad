defmodule PrzetargowyPrzegladWeb.Admin.DashboardLiveTest do
  use PrzetargowyPrzegladWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    # Add basic auth header
    credentials = Base.encode64("admin:admin")
    conn = put_req_header(conn, "authorization", "Basic #{credentials}")
    {:ok, conn: conn}
  end

  test "renders dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "Dashboard"
    assert html =~ "Subskrybenci"
  end

  test "shows subscriber stats", %{conn: conn} do
    # Create some test subscribers
    PrzetargowyPrzeglad.Subscribers.subscribe(%{email: "test@example.com"})

    {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "Oczekujących"
  end
end
