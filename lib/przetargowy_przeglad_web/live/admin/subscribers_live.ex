defmodule PrzetargowyPrzegladWeb.Admin.SubscribersLive do
  use PrzetargowyPrzegladWeb, :live_view

  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, :subscribers)
     |> assign(:page, 1)
     |> assign(:filters, %{status: nil, industry: nil, search: nil})
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_order, :desc)
     |> assign_subscribers()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")

    filters = %{
      status: params["status"],
      industry: params["industry"],
      search: params["search"]
    }

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:filters, filters)
     |> assign_subscribers()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    params = build_url_params(filters, 1)
    {:noreply, push_patch(socket, to: ~p"/admin/subscribers?#{params}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/subscribers")}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {sort_by, sort_order} =
      if socket.assigns.sort_by == field do
        {field, toggle_order(socket.assigns.sort_order)}
      else
        {field, :desc}
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign_subscribers()}
  end

  @impl true
  def handle_event("change_status", %{"id" => id, "status" => status}, socket) do
    subscriber = Subscribers.get_subscriber(id)

    case status do
      "confirmed" -> Subscribers.confirm_manually(subscriber)
      "unsubscribed" -> Subscribers.unsubscribe_by_admin(subscriber)
      _ -> {:error, :invalid_status}
    end

    {:noreply, assign_subscribers(socket)}
  end

  @impl true
  def handle_event("export_csv", _, socket) do
    subscribers = Subscribers.list_all_for_export(socket.assigns.filters)
    csv_content = generate_csv(subscribers)

    {:noreply,
     socket
     |> push_event("download", %{
       filename: "subscribers_#{Date.utc_today()}.csv",
       content: csv_content
     })}
  end

  defp assign_subscribers(socket) do
    %{page: page, filters: filters, sort_by: sort_by, sort_order: sort_order} = socket.assigns

    {subscribers, total_count} =
      Subscribers.list_paginated(
        page: page,
        per_page: @per_page,
        filters: filters,
        sort_by: sort_by,
        sort_order: sort_order
      )

    total_pages = ceil(total_count / @per_page)

    socket
    |> assign(:subscribers, subscribers)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp build_url_params(filters, page) do
    filters
    |> Map.put("page", page)
    |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

  defp generate_csv(subscribers) do
    headers = ["Email", "Imię", "Firma", "Branża", "Status", "Data zapisu", "Polecenia"]

    rows =
      Enum.map(subscribers, fn s ->
        [
          s.email,
          s.name || "",
          s.company_name || "",
          s.industry || "",
          s.status,
          Calendar.strftime(s.inserted_at, "%Y-%m-%d %H:%M"),
          s.referral_count
        ]
      end)

    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp sort_indicator(current_field, order, field) when current_field == field do
    if order == :asc, do: "↑", else: "↓"
  end

  defp sort_indicator(_, _, _), do: ""
end
