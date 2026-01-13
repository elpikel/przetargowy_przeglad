defmodule PrzetargowyPrzegladWeb.LandingLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @impl true
  def mount(_params, _session, socket) do
    changeset = Subscriber.signup_changeset(%Subscriber{}, %{})

    {:ok,
     assign(socket,
       form: to_form(changeset),
       submitted: false,
       error_message: nil
     )}
  end

  @impl true
  def handle_event("validate", %{"subscriber" => params}, socket) do
    changeset =
      %Subscriber{}
      |> Subscriber.signup_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("subscribe", %{"subscriber" => params}, socket) do
    case Subscribers.subscribe(params) do
      {:ok, _subscriber} ->
        # TODO: Wysłać email potwierdzający
        {:noreply, assign(socket, submitted: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
