defmodule PrzetargowyPrzegladWeb.LandingLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @impl true
  def mount(params, _session, socket) do
    referred_by = params["ref"]
    changeset = Subscriber.signup_changeset(%Subscriber{}, %{referred_by: referred_by})

    {:ok,
     socket
     |> assign(:changeset, changeset)
     |> assign(:referred_by, referred_by)
     |> assign(:submitted, false)
     |> assign(:show_preferences, false)}
  end

  @impl true
  def handle_event("validate", %{"subscriber" => params}, socket) do
    params = Map.put(params, "referred_by", socket.assigns.referred_by)

    changeset =
      %Subscriber{}
      |> Subscriber.signup_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("toggle_preferences", _, socket) do
    {:noreply, assign(socket, :show_preferences, !socket.assigns.show_preferences)}
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
  def handle_event("subscribe", %{"subscriber" => params}, socket) do
    params = Map.put(params, "referred_by", socket.assigns.referred_by)

    case Subscribers.subscribe(params) do
      {:ok, _subscriber} ->
        {:noreply, assign(socket, :submitted, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp industry_label("it"), do: "IT / Informatyka"
  defp industry_label("budowlana"), do: "Budowlana"
  defp industry_label("medyczna"), do: "Medyczna"
  defp industry_label("transportowa"), do: "Transportowa"
  defp industry_label("uslugi"), do: "Usługi"
  defp industry_label("dostawy"), do: "Dostawy"
  defp industry_label("inne"), do: "Inne"
  defp industry_label(other), do: String.capitalize(other)

  defp regions_list do
    [
      %{value: "dolnoslaskie", label: "Dolnośląskie"},
      %{value: "kujawsko-pomorskie", label: "Kujawsko-pomorskie"},
      %{value: "lubelskie", label: "Lubelskie"},
      %{value: "lubuskie", label: "Lubuskie"},
      %{value: "lodzkie", label: "Łódzkie"},
      %{value: "malopolskie", label: "Małopolskie"},
      %{value: "mazowieckie", label: "Mazowieckie"},
      %{value: "opolskie", label: "Opolskie"},
      %{value: "podkarpackie", label: "Podkarpackie"},
      %{value: "podlaskie", label: "Podlaskie"},
      %{value: "pomorskie", label: "Pomorskie"},
      %{value: "slaskie", label: "Śląskie"},
      %{value: "swietokrzyskie", label: "Świętokrzyskie"},
      %{value: "warminsko-mazurskie", label: "Warmińsko-mazurskie"},
      %{value: "wielkopolskie", label: "Wielkopolskie"},
      %{value: "zachodniopomorskie", label: "Zachodniopomorskie"}
    ]
  end

  defp subscriber_count do
    PrzetargowyPrzeglad.Subscribers.count_by_status("confirmed")
  end
end
