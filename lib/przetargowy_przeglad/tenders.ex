defmodule PrzetargowyPrzeglad.Tenders do
  @moduledoc """
  Context module for managing tenders.
  """

  import Ecto.Query, warn: false

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.Tender

  # =============================================================================
  # Basic CRUD
  # =============================================================================

  @doc """
  Gets a single tender by ID.
  """
  def get_tender(id), do: Repo.get(Tender, id)

  @doc """
  Gets a tender by external_id and source.
  """
  def get_by_external(external_id, source) do
    Repo.get_by(Tender, external_id: external_id, source: source)
  end

  @doc """
  Upserts a single tender. Updates on conflict.
  """
  def upsert_tender(attrs) do
    %Tender{}
    |> Tender.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:external_id, :source]
    )
  end

  @doc """
  Upserts multiple tenders in bulk.
  Returns `{success_count, failed_list}`.
  """
  def upsert_tenders(tenders_attrs) when is_list(tenders_attrs) do
    results =
      Enum.map(tenders_attrs, fn attrs ->
        case upsert_tender(attrs) do
          {:ok, tender} -> {:ok, tender}
          {:error, changeset} -> {:error, attrs, changeset}
        end
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.filter(results, &match?({:error, _, _}, &1))

    {success_count, failed}
  end

  @doc """
  Lists all tenders with optional filters.
  """
  def list_tenders(opts \\ []) do
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0

    Tender
    |> apply_filters(opts)
    |> order_by([t], desc: t.publication_date)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Lists recent tenders from last N days.
  """
  def list_recent(days \\ 7) do
    since = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    Tender
    |> where([t], t.publication_date >= ^since)
    |> order_by([t], desc: t.publication_date)
    |> Repo.all()
  end

  @doc """
  Counts all tenders.
  """
  def count_all do
    Repo.aggregate(Tender, :count)
  end

  @doc """
  Returns the last fetch timestamp.
  """
  def last_fetched_at do
    Tender
    |> select([t], max(t.fetched_at))
    |> Repo.one()
  end

  # =============================================================================
  # Newsletter Functions
  # =============================================================================

  @doc """
  Gets top tenders for newsletter (by value, active deadline).
  """
  def get_top_for_newsletter(limit \\ 5) do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)
    now = DateTime.utc_now()

    Tender
    |> where([t], t.publication_date >= ^week_ago)
    |> where([t], t.submission_deadline > ^now)
    |> where([t], not is_nil(t.estimated_value))
    |> order_by([t], desc: t.estimated_value)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets top tenders for a specific subscriber based on their preferences.
  """
  def get_top_for_subscriber(subscriber, limit \\ 5) do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)
    now = DateTime.utc_now()

    industry = get_subscriber_field(subscriber, :industry)
    regions = get_subscriber_field(subscriber, :regions) || []

    Tender
    |> where([t], t.publication_date >= ^week_ago)
    |> where([t], t.submission_deadline > ^now)
    |> maybe_filter_by_industry(industry)
    |> maybe_filter_by_regions(regions)
    |> where([t], not is_nil(t.estimated_value))
    |> order_by([t], desc: t.estimated_value)
    |> limit(^limit)
    |> Repo.all()
  end

  # =============================================================================
  # Statistics
  # =============================================================================

  @doc """
  Gets weekly statistics for all tenders.
  """
  def get_weekly_stats do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

    tenders =
      Tender
      |> where([t], t.publication_date >= ^week_ago)
      |> Repo.all()

    %{
      total_count: length(tenders),
      total_value: sum_values(tenders),
      avg_value: avg_value(tenders),
      by_industry: group_count(tenders, :industry),
      by_region: group_count(tenders, :contracting_authority_region),
      top_industries: top_industries(tenders, 5)
    }
  end

  @doc """
  Gets weekly statistics for a specific industry.
  """
  def get_weekly_stats_for_industry(industry) when is_binary(industry) and industry != "" do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

    tenders =
      Tender
      |> where([t], t.publication_date >= ^week_ago)
      |> where([t], t.industry == ^industry)
      |> Repo.all()

    %{
      total_count: length(tenders),
      total_value: sum_values(tenders),
      avg_value: avg_value(tenders),
      by_region: group_count(tenders, :contracting_authority_region)
    }
  end

  def get_weekly_stats_for_industry(_), do: get_weekly_stats()

  @doc """
  Gets weekly statistics for specific regions.
  """
  def get_weekly_stats_for_regions(regions) when is_list(regions) and length(regions) > 0 do
    week_ago = DateTime.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

    tenders =
      Tender
      |> where([t], t.publication_date >= ^week_ago)
      |> where([t], t.contracting_authority_region in ^regions)
      |> Repo.all()

    %{
      total_count: length(tenders),
      total_value: sum_values(tenders),
      avg_value: avg_value(tenders),
      by_industry: group_count(tenders, :industry)
    }
  end

  def get_weekly_stats_for_regions(_), do: get_weekly_stats()

  # =============================================================================
  # Private Helpers
  # =============================================================================

  defp get_subscriber_field(subscriber, field) when is_map(subscriber) do
    Map.get(subscriber, field) || Map.get(subscriber, to_string(field))
  end

  defp apply_filters(query, opts) do
    query
    |> maybe_filter_by_industry(opts[:industry])
    |> maybe_filter_by_regions(opts[:regions])
    |> maybe_filter_by_date_range(opts[:from], opts[:to])
  end

  defp maybe_filter_by_industry(query, nil), do: query
  defp maybe_filter_by_industry(query, ""), do: query

  defp maybe_filter_by_industry(query, industry) do
    where(query, [t], t.industry == ^industry)
  end

  defp maybe_filter_by_regions(query, nil), do: query
  defp maybe_filter_by_regions(query, []), do: query

  defp maybe_filter_by_regions(query, regions) when is_list(regions) do
    where(query, [t], t.contracting_authority_region in ^regions)
  end

  defp maybe_filter_by_date_range(query, nil, nil), do: query

  defp maybe_filter_by_date_range(query, from, nil) do
    where(query, [t], t.publication_date >= ^from)
  end

  defp maybe_filter_by_date_range(query, nil, to) do
    where(query, [t], t.publication_date <= ^to)
  end

  defp maybe_filter_by_date_range(query, from, to) do
    where(query, [t], t.publication_date >= ^from and t.publication_date <= ^to)
  end

  defp sum_values(tenders) do
    tenders
    |> Enum.map(& &1.estimated_value)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp avg_value(tenders) do
    values =
      tenders
      |> Enum.map(& &1.estimated_value)
      |> Enum.reject(&is_nil/1)

    case length(values) do
      0 -> Decimal.new(0)
      n -> Decimal.div(sum_values(tenders), n)
    end
  end

  defp group_count(tenders, field) do
    tenders
    |> Enum.group_by(&Map.get(&1, field))
    |> Enum.reject(fn {k, _} -> is_nil(k) end)
    |> Map.new(fn {k, v} -> {k, length(v)} end)
  end

  defp top_industries(tenders, limit) do
    tenders
    |> Enum.group_by(& &1.industry)
    |> Enum.reject(fn {k, _} -> is_nil(k) end)
    |> Enum.map(fn {industry, items} -> %{name: industry, count: length(items)} end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(limit)
  end
end
