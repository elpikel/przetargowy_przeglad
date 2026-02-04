defmodule PrzetargowyPrzegladWeb.Plugs.RawBodyReader do
  @moduledoc """
  Plug that captures the raw request body before parsing.

  This is required for webhook signature verification (e.g., Stripe)
  where the exact raw bytes are needed to verify the HMAC signature.
  """

  @doc """
  Custom body reader that caches the raw body in conn.assigns.
  Used as :body_reader option for Plug.Parsers.
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = update_in(conn.assigns[:raw_body], &((&1 || "") <> body))
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = update_in(conn.assigns[:raw_body], &((&1 || "") <> body))
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
