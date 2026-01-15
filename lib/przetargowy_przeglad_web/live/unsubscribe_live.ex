defmodule PrzetargowyPrzegladWeb.UnsubscribeLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers

  @impl true
  def mount(%{"email" => email} = _params, _session, socket) do
    {:ok,
     assign(socket,
       email: email,
       status: :pending,
       error: nil
     )}
  end

  @impl true
  def handle_event("confirm_unsubscribe", _, socket) do
    case Subscribers.unsubscribe(socket.assigns.email) do
      {:ok, _} ->
        {:noreply, assign(socket, status: :unsubscribed)}

      {:error, :not_found} ->
        {:noreply, assign(socket, status: :not_found)}
    end
  end
end
