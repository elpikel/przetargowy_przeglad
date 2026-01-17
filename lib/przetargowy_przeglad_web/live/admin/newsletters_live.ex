defmodule PrzetargowyPrzegladWeb.Admin.NewslettersLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Newsletters
  alias PrzetargowyPrzeglad.Workers.{GenerateNewsletterWorker, SendNewsletterWorker}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, :newsletters)
     |> assign(:newsletters, Newsletters.list_newsletters(limit: 20))}
  end

  @impl true
  def handle_event("generate_now", _, socket) do
    case GenerateNewsletterWorker.enqueue() do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Newsletter zostanie wygenerowany w tle.")
         |> assign(:newsletters, Newsletters.list_newsletters(limit: 20))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Błąd przy planowaniu generacji.")}
    end
  end

  @impl true
  def handle_event("send_now", %{"id" => id}, socket) do
    case SendNewsletterWorker.enqueue(String.to_integer(id)) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Newsletter zostanie wysłany w tle.")
         |> assign(:newsletters, Newsletters.list_newsletters(limit: 20))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Błąd przy planowaniu wysyłki.")}
    end
  end

  @impl true
  def handle_event("refresh", _, socket) do
    {:noreply, assign(socket, :newsletters, Newsletters.list_newsletters(limit: 20))}
  end

  defp status_label("draft"), do: "Szkic"
  defp status_label("generated"), do: "Gotowy"
  defp status_label("sending"), do: "Wysyłanie..."
  defp status_label("sent"), do: "Wysłany"
  defp status_label(other), do: other

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%d.%m.%Y %H:%M")
end
