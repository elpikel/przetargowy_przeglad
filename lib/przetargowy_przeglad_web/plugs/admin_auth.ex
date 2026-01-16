defmodule PrzetargowyPrzegladWeb.Plugs.AdminAuth do
  @moduledoc """
  Basic HTTP Authentication for admin routes.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    config = Application.get_env(:przetargowy_przeglad, :admin_auth)
    expected_username = config[:username]
    expected_password = config[:password]

    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, credentials} ->
            case String.split(credentials, ":", parts: 2) do
              [^expected_username, ^expected_password] ->
                conn

              _ ->
                unauthorized(conn)
            end

          :error ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", ~s(Basic realm="Admin Area"))
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
