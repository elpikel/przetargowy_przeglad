defmodule PrzetargowyPrzegladWeb.SessionController do
  use PrzetargowyPrzegladWeb, :controller

  plug :put_layout, false
  plug :put_root_layout, false

  def show_login(conn, _params) do
    render(conn, :show_login)
  end

  def create_session(conn, %{"session" => session_params}) do
    # TODO: Implement authentication logic
    # For now, this is a placeholder
    email = session_params["email"]
    password = session_params["password"]

    # TODO: Verify credentials against database
    # TODO: Create session and store user_id
    # TODO: Redirect to appropriate page on success

    conn
    |> put_flash(:error, "Invalid email or password")
    |> render(:show_login)
  end
end
