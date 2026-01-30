defmodule PrzetargowyPrzeglad.Workers.FetchTendersNotices do
  @moduledoc """
  Oban worker for fetching tenders notices from BZP API.
  Runs daily to fetch new and updated tenders notices.

  ## Arguments
  - `days` - Number of days back to fetch tenders notices from (defaults to 1)
  """
  use Oban.Worker,
    queue: :tenders,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Bzp.Client, as: BZPClient
  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    days = args["days"] || 1

    publication_date_from = Date.utc_today() |> Date.add(-days) |> Date.to_iso8601()
    publication_date_to = Date.to_iso8601(Date.utc_today())

    Logger.info("Starting tender notices fetch from #{publication_date_from} to #{publication_date_to} (#{days} days)")

    upsert_all_tender_notices(publication_date_from, publication_date_to)

    :ok
  end

  @doc """
  Upserts all tender notices published between the given dates.
  publication_date_from = Date.utc_today() |> Date.shift(year: -2) |> Date.to_iso8601()
  publication_date_to = Date.to_iso8601(Date.utc_today())
  PrzetargowyPrzeglad.Workers.FetchTendersNotices.upsert_all_tender_notices(publication_date_from, publication_date_to)
  """
  def upsert_all_tender_notices(publication_date_from, publication_date_to) do
    for notice_type <- TenderNotice.notice_types() do
      Logger.info("Starting upsert for notice type: #{notice_type}")

      last_object_id = Tenders.get_last_object_id_by_notice_type(notice_type)
      upsert_all_tender_notices(last_object_id, publication_date_from, publication_date_to, notice_type)
    end
  end

  defp upsert_all_tender_notices(object_id, publication_date_from, publication_date_to, notice_type) do
    case BZPClient.fetch_tenders_notices(object_id, publication_date_from, publication_date_to, notice_type) do
      {:ok, %{tenders: []}} ->
        Logger.info("BZP API: No more results.")
        :ok

      {:ok, %{tenders: tenders}} ->
        Logger.info("BZP API: Got #{length(tenders)} tenders")
        # Rate limiting
        Process.sleep(200)

        {_success_count, failed} = Tenders.upsert_tender_notices(tenders)

        if length(failed) > 0 do
          raise "Failed to upsert #{length(failed)} tender notices"
        end

        last_tender = List.last(tenders)
        next_object_id = last_tender.object_id

        upsert_all_tender_notices(next_object_id, publication_date_from, publication_date_to, notice_type)

      {:error, reason} ->
        Logger.error("BZP API: Error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
