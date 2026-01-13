defmodule PrzetargowyPrzegladWeb.ConfirmLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if connected?(socket) do
      case Subscribers.confirm_subscription(token) do
        {:ok, subscriber} ->
          {:ok, assign(socket, status: :confirmed, subscriber: subscriber)}

        {:error, :invalid_token} ->
          {:ok, assign(socket, status: :invalid_token)}

        {:error, :already_confirmed} ->
          {:ok, assign(socket, status: :already_confirmed)}
      end
    else
      {:ok, assign(socket, status: :pending)}
    end
  end
end
