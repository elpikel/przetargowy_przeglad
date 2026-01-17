defmodule PrzetargowyPrzegladWeb.Admin.SubscribersLiveTest do
  use PrzetargowyPrzegladWeb.ConnCase
  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    credentials = Base.encode64("admin:admin")
    conn = put_req_header(conn, "authorization", "Basic #{credentials}")

    # Create test data
    {:ok, sub} =
      PrzetargowyPrzeglad.Subscribers.subscribe(%{
        email: "test@example.com",
        name: "Test User"
      })

    {:ok, conn: conn, subscriber: sub}
  end

  test "lists subscribers", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/subscribers")

    assert html =~ "test@example.com"
  end

  test "filters by status", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/subscribers")

    # Use form's phx-change event since phx-change is on the form element
    html =
      view
      |> form("form[phx-change='filter']", %{filters: %{status: "pending"}})
      |> render_change()

    assert html =~ "test@example.com"
  end
end
