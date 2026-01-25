defmodule PrzetargowyPrzeglad.Workers.FetchTendersNoticesWorker do
  @moduledoc """
  Oban worker for fetching tenders notices from BZP API.
  Runs daily to fetch new and updated tenders notices.

  ## Arguments
  - `days` - Number of days back to fetch tenders notices from (defaults to 1)
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Bzp.Client, as: BZPClient
  alias PrzetargowyPrzeglad.Tenders

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    days = args["days"] || 1

    publication_date_from = Date.utc_today() |> Date.add(-days) |> Date.to_iso8601()
    publication_date_to = Date.to_iso8601(Date.utc_today())

    Logger.info("Starting tender notices fetch from #{publication_date_from} to #{publication_date_to} (#{days} days)")

    case BZPClient.fetch_all_tender_notices(publication_date_from, publication_date_to) do
      {:ok,
       %{
         tenders: tenders,
         total: _total,
         page: _page
       }}
      when is_list(tenders) ->
        Logger.info("Fetched #{length(tenders)} tenders notices from BZP")

        {success_count, failed} = Tenders.upsert_tender_notices(tenders)

        if length(failed) > 0 do
          Logger.warning("Failed to upsert #{length(failed)} tenders notices")
        end

        Logger.info("Tender notices fetch complete. Inserted/Updated: #{success_count}, Failed: #{length(failed)}")

        {:ok, %{fetched: length(tenders), inserted: success_count, failed: length(failed)}}

      {:ok, []} ->
        Logger.info("No new tenders notices found")
        {:ok, %{fetched: 0, inserted: 0, failed: 0}}

      {:error, reason} ->
        Logger.error("Failed to fetch tenders notices: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Upserts all tender notices published between the given dates.
  publication_date_from = Date.utc_today() |> Date.shift(year: -2) |> Date.to_iso8601()
  publication_date_to = Date.to_iso8601(Date.utc_today())
  PrzetargowyPrzeglad.Workers.FetchTendersNoticesWorker.upsert_all_tender_notices(publication_date_from, publication_date_to)
  """
  def upsert_all_tender_notices(publication_date_from, publication_date_to) do
    upsert_all_tender_notices(nil, publication_date_from, publication_date_to)
  end

  defp upsert_all_tender_notices(object_id, publication_date_from, publication_date_to) do
    case BZPClient.fetch_tenders_notices(object_id, publication_date_from, publication_date_to) do
      {:ok, %{tenders: []}} ->
        Logger.info("BZP API: No more results.")
        :ok

      {:ok, %{tenders: tenders}} ->
        Logger.info("BZP API: Got #{length(tenders)} tenders")
        # Rate limiting
        Process.sleep(200)

        Tenders.upsert_tender_notices(tenders)

        last_tender = List.last(tenders)
        next_object_id = last_tender.object_id

        upsert_all_tender_notices(next_object_id, publication_date_from, publication_date_to)

      {:error, reason} ->
        Logger.error("BZP API: Error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
