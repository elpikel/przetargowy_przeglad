defmodule PrzetargowyPrzegladWeb.Admin.NewsletterShowLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Newsletters
  alias PrzetargowyPrzeglad.Email.NewsletterEmail
  alias PrzetargowyPrzeglad.Mailer
  alias PrzetargowyPrzeglad.Workers.SendNewsletterWorker

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    newsletter = Newsletters.get_newsletter(id)

    if newsletter do
      {:ok,
       socket
       |> assign(:current_page, :newsletters)
       |> assign(:newsletter, newsletter)
       |> assign(:preview_mode, :html)
       |> assign(:test_email, "")
       |> assign(:test_sent, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Newsletter nie znaleziony")
       |> push_navigate(to: ~p"/admin/newsletters")}
    end
  end

  @impl true
  def handle_event("toggle_preview", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :preview_mode, String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("update_test_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, :test_email, email)}
  end

  @impl true
  def handle_event("send_test", _, socket) do
    email = socket.assigns.test_email
    newsletter = socket.assigns.newsletter

    if email != "" and String.contains?(email, "@") do
      # Tworzymy fake subscriber dla testu
      test_subscriber = %{
        email: email,
        name: "Test User",
        referral_code: "TEST123"
      }

      case send_test_email(newsletter, test_subscriber) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:test_sent, true)
           |> put_flash(:info, "Email testowy wysłany na #{email}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Błąd wysyłki: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Podaj prawidłowy adres email")}
    end
  end

  @impl true
  def handle_event("send_now", _, socket) do
    newsletter = socket.assigns.newsletter

    case SendNewsletterWorker.enqueue(newsletter.id) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Newsletter zostanie wysłany w tle.")
         |> push_navigate(to: ~p"/admin/newsletters")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Błąd przy planowaniu wysyłki.")}
    end
  end

  defp send_test_email(newsletter, subscriber) do
    newsletter
    |> NewsletterEmail.build(subscriber)
    |> Mailer.deliver()
  end

  defp preview_html(newsletter) do
    # Zamień placeholdery na przykładowe wartości
    newsletter.content_html
    |> String.replace("{{subscriber_name_greeting}}", " Test User")
    |> String.replace("{{referral_code}}", "ABC123")
    |> String.replace("{{unsubscribe_url}}", "#unsubscribe")
    |> String.replace("{{preferences_url}}", "#preferences")
  end

  defp status_label("draft"), do: "Szkic"
  defp status_label("generated"), do: "Gotowy"
  defp status_label("sending"), do: "Wysyłanie..."
  defp status_label("sent"), do: "Wysłany"
  defp status_label(other), do: other

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%d.%m.%Y %H:%M")
end
