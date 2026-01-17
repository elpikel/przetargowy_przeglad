defmodule PrzetargowyPrzegladWeb.PreferencesLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @impl true
  def mount(%{"email" => email, "token" => token}, _session, socket) do
    if valid_token?(email, token) do
      case Subscribers.get_by_email(email) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Nie znaleziono subskrypcji")
           |> push_navigate(to: ~p"/")}

        subscriber ->
          changeset = Subscriber.preferences_changeset(subscriber, %{})

          {:ok,
           socket
           |> assign(:subscriber, subscriber)
           |> assign(:changeset, changeset)
           |> assign(:saved, false)}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "Nieprawidłowy link")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"subscriber" => params}, socket) do
    changeset =
      socket.assigns.subscriber
      |> Subscriber.preferences_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("toggle_region", %{"region" => region}, socket) do
    changeset = socket.assigns.changeset
    current_regions = Ecto.Changeset.get_field(changeset, :regions) || []

    new_regions =
      if region in current_regions do
        List.delete(current_regions, region)
      else
        [region | current_regions]
      end

    changeset = Ecto.Changeset.put_change(changeset, :regions, new_regions)
    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"subscriber" => params}, socket) do
    case Subscribers.update_preferences(socket.assigns.subscriber, params) do
      {:ok, subscriber} ->
        {:noreply,
         socket
         |> assign(:subscriber, subscriber)
         |> assign(:saved, true)
         |> put_flash(:info, "Preferencje zapisane!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp valid_token?(email, token) do
    secret = Application.get_env(:przetargowy_przeglad, :secret_key_base, "dev_secret")

    expected =
      :crypto.mac(:hmac, :sha256, secret, email)
      |> Base.url_encode64(padding: false)
      |> String.slice(0, 16)

    Plug.Crypto.secure_compare(token, expected)
  end
end
