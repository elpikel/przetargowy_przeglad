defmodule PrzetargowyPrzeglad.Tenders do
  @moduledoc """
  Context module for managing tenders.
  """

  import Ecto.Query

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  require Logger

  @doc """
  Gets the last inserted tender notice's object_id for the given notice type.
  """
  def get_last_object_id_by_notice_type(notice_type) do
    TenderNotice
    |> from(as: :tender_notice)
    |> where([tender_notice: tn], tn.notice_type == ^notice_type)
    |> order_by([tender_notice: tn], desc: tn.inserted_at)
    |> limit(1)
    |> select([tender_notice: tn], tn.object_id)
    |> Repo.one()
  end

  @doc """
  Gets a single tender notice by ID.
  """
  def get_tender_notice(id), do: Repo.get_by(TenderNotice, object_id: id)

  @doc """
  Gets a single tender notice by BZP number.
  """
  def get_tender_by_bzp_number(bzp_number), do: Repo.get_by(TenderNotice, bzp_number: bzp_number)

  @doc """
  Searches tender notices with optional filters.

  ## Options
    * `:query` - text search in order_object and organization_name
    * `:regions` - list of regions to filter by (or single region string for backwards compatibility)
    * `:order_types` - list of order types (Delivery, Services, Works) or single string
    * `:notice_type` - filter by notice type (default: ContractNotice)
    * `:page` - page number (default: 1)
    * `:per_page` - results per page (default: 20)
  """
  def search_tender_notices(opts \\ []) do
    query = Keyword.get(opts, :query)
    regions = normalize_to_list(Keyword.get(opts, :regions))
    order_types = normalize_to_list(Keyword.get(opts, :order_types))
    notice_type = Keyword.get(opts, :notice_type, "ContractNotice")
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    offset = (page - 1) * per_page

    base_query =
      TenderNotice
      |> from(as: :tender_notice)
      |> where([tender_notice: tn], tn.notice_type == ^notice_type)
      |> where([tender_notice: tn], tn.submitting_offers_date >= ^DateTime.utc_now())

    base_query =
      if query && query != "" do
        search_term = "%#{query}%"

        where(
          base_query,
          [tender_notice: tn],
          ilike(tn.order_object, ^search_term) or ilike(tn.organization_name, ^search_term)
        )
      else
        base_query
      end

    base_query =
      if regions == [] do
        base_query
      else
        province_codes = regions |> Enum.map(&region_to_province_code/1) |> Enum.filter(& &1)
        where(base_query, [tender_notice: tn], tn.organization_province in ^province_codes)
      end

    base_query =
      if order_types == [] do
        base_query
      else
        where(base_query, [tender_notice: tn], tn.order_type in ^order_types)
      end

    total_count =
      base_query
      |> select([tender_notice: tn], count(tn.object_id))
      |> Repo.one()

    notices =
      base_query
      |> order_by([tender_notice: tn], asc: tn.submitting_offers_date)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    total_pages = ceil(total_count / per_page)

    %{
      notices: notices,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
  end

  defp normalize_to_list(nil), do: []
  defp normalize_to_list(""), do: []
  defp normalize_to_list(list) when is_list(list), do: Enum.filter(list, &(&1 != "" && &1 != nil))
  defp normalize_to_list(value) when is_binary(value), do: [value]

  defp region_to_province_code(region) do
    case region do
      "dolnoslaskie" -> "PL02"
      "kujawsko-pomorskie" -> "PL04"
      "lubelskie" -> "PL06"
      "lubuskie" -> "PL08"
      "lodzkie" -> "PL10"
      "malopolskie" -> "PL12"
      "mazowieckie" -> "PL14"
      "opolskie" -> "PL16"
      "podkarpackie" -> "PL18"
      "podlaskie" -> "PL20"
      "pomorskie" -> "PL22"
      "slaskie" -> "PL24"
      "swietokrzyskie" -> "PL26"
      "warminsko-mazurskie" -> "PL28"
      "wielkopolskie" -> "PL30"
      "zachodniopomorskie" -> "PL32"
      _ -> nil
    end
  end

  @doc """
  Upserts a single tender notice. Updates on conflict.
  """
  def upsert_tender_notice(attrs) do
    %TenderNotice{}
    |> TenderNotice.changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:object_id]
    )
  end

  @doc """
  Upserts multiple tender notices in bulk.
  Returns `{success_count, failed_list}`.
  """
  def upsert_tender_notices(tender_notices_attrs) when is_list(tender_notices_attrs) do
    results =
      Enum.map(tender_notices_attrs, fn attrs ->
        case upsert_tender_notice(attrs) do
          {:ok, tender_notice} ->
            {:ok, tender_notice}

          {:error, changeset} ->
            Logger.error("Failed to upsert tender notice #{inspect(attrs["object_id"])}: #{inspect(changeset)}")

            {:error, attrs, changeset}
        end
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.filter(results, &match?({:error, _, _}, &1))

    {success_count, failed}
  end
end
