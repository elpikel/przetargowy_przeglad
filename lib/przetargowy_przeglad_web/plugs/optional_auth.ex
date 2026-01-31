defmodule PrzetargowyPrzegladWeb.Plugs.OptionalAuth do
  @moduledoc """
  Plug that optionally loads the current user if logged in.
  Does not require authentication - assigns nil if not logged in.
  """
  import Plug.Conn

  alias PrzetargowyPrzeglad.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> clear_session()
            |> assign(:current_user, nil)

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
