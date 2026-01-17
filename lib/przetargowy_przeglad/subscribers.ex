defmodule PrzetargowyPrzeglad.Subscribers do
  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  @confirmed Subscriber.confirmed()

  def subscribe(attrs) do
    %Subscriber{}
    |> Subscriber.signup_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, subscriber} ->
        send_confirmation_email(subscriber)
        {:ok, subscriber}

      error ->
        error
    end
  end

  def confirm_subscription(token) do
    subscription =
      Subscriber
      |> from(as: :subscriber)
      |> where(
        [subscriber: s],
        s.confirmation_token == ^token
      )
      |> Repo.one()

    case subscription do
      nil ->
        {:error, :invalid_token}

      %Subscriber{status: @confirmed} ->
        {:error, :already_confirmed}

      subscriber ->
        subscriber
        |> Subscriber.confirm_changeset()
        |> Repo.update()
    end
  end

  def unsubscribe(email) do
    case get_by_email(email) do
      nil ->
        {:error, :not_found}

      subscriber ->
        subscriber
        |> Subscriber.unsubscribe_changeset()
        |> Repo.update()
    end
  end

  def get_by_email(email) do
    Repo.get_by(Subscriber, email: String.downcase(email))
  end

  def get_by_token(token) do
    Repo.get_by(Subscriber, confirmation_token: token) |> IO.inspect()
  end

  def list_confirmed do
    Subscriber
    |> where([s], s.status == @confirmed)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def count_by_status do
    Subscriber
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  def get_stats do
    %{
      total: count_all(),
      confirmed: count_by_status("confirmed"),
      pending: count_by_status("pending"),
      unsubscribed: count_by_status("unsubscribed"),
      by_industry: count_by_industry(),
      by_region: count_by_region()
    }
  end

  def count_all do
    Repo.aggregate(Subscriber, :count)
  end

  def count_by_status(status) do
    Subscriber
    |> where([s], s.status == ^status)
    |> Repo.aggregate(:count)
  end

  def list_recent(limit \\ 10) do
    Subscriber
    |> order_by([s], desc: s.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_paginated(opts \\ []) do
    page = opts[:page] || 1
    per_page = opts[:per_page] || 20
    filters = opts[:filters] || %{}
    sort_by = opts[:sort_by] || :inserted_at
    sort_order = opts[:sort_order] || :desc

    query =
      Subscriber
      |> apply_filters(filters)
      |> apply_sorting(sort_by, sort_order)

    total_count = Repo.aggregate(query, :count)

    subscribers =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    {subscribers, total_count}
  end

  def list_all_for_export(filters \\ %{}) do
    Subscriber
    |> apply_filters(filters)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_subscriber(id) do
    Repo.get(Subscriber, id)
  end

  def confirm_manually(subscriber) do
    subscriber
    |> Subscriber.confirm_changeset()
    |> Repo.update()
  end

  def unsubscribe_by_admin(subscriber) do
    subscriber
    |> Subscriber.unsubscribe_changeset()
    |> Repo.update()
  end

  def update_preferences(subscriber, attrs) do
    subscriber
    |> Subscriber.preferences_changeset(attrs)
    |> Repo.update()
  end

  defp apply_filters(query, filters) do
    query
    |> filter_by_status(filters[:status] || filters["status"])
    |> filter_by_industry(filters[:industry] || filters["industry"])
    |> filter_by_search(filters[:search] || filters["search"])
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, ""), do: query

  defp filter_by_status(query, status) do
    where(query, [s], s.status == ^status)
  end

  defp filter_by_industry(query, nil), do: query
  defp filter_by_industry(query, ""), do: query

  defp filter_by_industry(query, industry) do
    where(query, [s], s.industry == ^industry)
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_term = "%#{search}%"

    where(
      query,
      [s],
      ilike(s.email, ^search_term) or
        ilike(s.company_name, ^search_term) or
        ilike(s.name, ^search_term)
    )
  end

  defp apply_sorting(query, field, order) do
    order_by(query, [s], [{^order, field(s, ^field)}])
  end

  defp count_by_industry do
    Subscriber
    |> where([s], s.status == "confirmed")
    |> where([s], not is_nil(s.industry))
    |> group_by([s], s.industry)
    |> select([s], {s.industry, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp count_by_region do
    Subscriber
    |> where([s], s.status == "confirmed")
    |> Repo.all()
    |> Enum.flat_map(& &1.regions)
    |> Enum.frequencies()
  end

  defp send_confirmation_email(subscriber) do
    subscriber
    |> PrzetargowyPrzeglad.Email.ConfirmationEmail.build()
    |> PrzetargowyPrzeglad.Mailer.deliver()
  end
end
