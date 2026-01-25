defmodule PrzetargowyPrzeglad.Tenders do
  @moduledoc """
  Context module for managing tenders.
  """

  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  @doc """
  Gets a single tender notice by ID.
  """
  def get_tender_notice(id), do: Repo.get_by(TenderNotice, object_id: id)

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
            IO.inspect({:error, attrs, changeset})
            raise {:error, attrs, changeset}
        end
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.filter(results, &match?({:error, _, _}, &1))

    {success_count, failed}
  end
end
