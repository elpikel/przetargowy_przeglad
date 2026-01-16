defmodule PrzetargowyPrzeglad.Tenders do
  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.Tender

  @doc """
  Upsert a single tender.
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
  Bulk upsert tenders.
  """
  def upsert_tenders(tenders_list) do
    results = Enum.map(tenders_list, &upsert_tender/1)

    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    %{
      inserted: length(successes),
      failed: length(failures),
      errors: Enum.map(failures, fn {:error, cs} -> cs.errors end)
    }
  end

  @doc """
  Gets a tender by ID.
  """
  def get_tender(id), do: Repo.get(Tender, id)

  @doc """
  Gets a tender by external_id and source.
  """
  def get_by_external(external_id, source) do
    Repo.get_by(Tender, external_id: external_id, source: source)
  end

  @doc """
  Lists tenders with filters.
  """
  def list_tenders(opts \\ []) do
    Tender
    |> apply_filters(opts)
    |> apply_ordering(opts[:order_by])
    |> apply_limit(opts[:limit])
    |> Repo.all()
  end

  @doc """
  Tenders from the last N days.
  """
  def list_recent(days \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    Tender
    |> where([t], t.publication_date >= ^cutoff)
    |> order_by([t], desc: t.publication_date)
    |> Repo.all()
  end

  @doc """
  Top tenders for newsletter.
  """
  def get_top_for_newsletter(limit \\ 5) do
    week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)
    now = DateTime.utc_now()

    Tender
    |> where([t], t.publication_date >= ^week_ago)
    |> where([t], not is_nil(t.estimated_value))
    |> where([t], t.submission_deadline > ^now)
    |> order_by([t], desc: t.estimated_value)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Weekly statistics.
  """
  def get_weekly_stats do
    week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)

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
      top_industries: top_groups(tenders, :industry, 3)
    }
  end

  @doc """
  Number of tenders in the database.
  """
  def count_all do
    Repo.aggregate(Tender, :count)
  end

  @doc """
  Date of last fetch.
  """
  def last_fetched_at do
    Tender
    |> select([t], max(t.fetched_at))
    |> Repo.one()
  end

  # Private: Filters

  defp apply_filters(query, opts) do
    query
    |> filter_by(:industry, opts[:industry])
    |> filter_by(:contracting_authority_region, opts[:region])
    |> filter_by_value_range(opts[:min_value], opts[:max_value])
    |> filter_by_deadline(opts[:deadline_after])
    |> filter_by_publication(opts[:published_after])
  end

  defp filter_by(query, _field, nil), do: query

  defp filter_by(query, field, value) do
    where(query, [t], field(t, ^field) == ^value)
  end

  defp filter_by_value_range(query, nil, nil), do: query

  defp filter_by_value_range(query, min, nil) do
    where(query, [t], t.estimated_value >= ^min)
  end

  defp filter_by_value_range(query, nil, max) do
    where(query, [t], t.estimated_value <= ^max)
  end

  defp filter_by_value_range(query, min, max) do
    where(query, [t], t.estimated_value >= ^min and t.estimated_value <= ^max)
  end

  defp filter_by_deadline(query, nil), do: query

  defp filter_by_deadline(query, date) do
    where(query, [t], t.submission_deadline >= ^date)
  end

  defp filter_by_publication(query, nil), do: query

  defp filter_by_publication(query, date) do
    where(query, [t], t.publication_date >= ^date)
  end

  defp apply_ordering(query, nil), do: order_by(query, [t], desc: t.publication_date)
  defp apply_ordering(query, :value_desc), do: order_by(query, [t], desc: t.estimated_value)
  defp apply_ordering(query, :value_asc), do: order_by(query, [t], asc: t.estimated_value)
  defp apply_ordering(query, :deadline), do: order_by(query, [t], asc: t.submission_deadline)
  defp apply_ordering(query, _), do: order_by(query, [t], desc: t.publication_date)

  defp apply_limit(query, nil), do: limit(query, 50)
  defp apply_limit(query, n), do: limit(query, ^n)

  # Private: Stats helpers

  defp sum_values(tenders) do
    tenders
    |> Enum.map(& &1.estimated_value)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp avg_value(tenders) do
    values = tenders |> Enum.map(& &1.estimated_value) |> Enum.reject(&is_nil/1)

    case length(values) do
      0 -> Decimal.new(0)
      n -> Decimal.div(sum_values(tenders), n)
    end
  end

  defp group_count(tenders, field) do
    tenders
    |> Enum.group_by(&Map.get(&1, field))
    |> Enum.map(fn {k, v} -> {k || "nieokreślone", length(v)} end)
    |> Map.new()
  end

  defp top_groups(tenders, field, limit) do
    tenders
    |> group_count(field)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {name, count} -> %{name: name, count: count} end)
  end
end
