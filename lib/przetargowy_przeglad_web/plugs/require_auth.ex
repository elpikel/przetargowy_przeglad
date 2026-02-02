defmodule PrzetargowyPrzegladWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that ensures a user is authenticated.
  Redirects to login page if no user is logged in.
  """
  import Phoenix.Controller
  import Plug.Conn

  alias PrzetargowyPrzeglad.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> redirect(to: "/login")
        |> halt()

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> clear_session()
            |> redirect(to: "/login")
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
