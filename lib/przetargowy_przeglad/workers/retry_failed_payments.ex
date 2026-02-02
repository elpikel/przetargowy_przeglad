defmodule PrzetargowyPrzeglad.Workers.RetryFailedPayments do
  @moduledoc """
  Oban worker that retries failed subscription payments.

  ## Retry Logic

  1. Finds subscriptions with failed payments that can still be retried
  2. Attempts to charge the saved card again
  3. On 3rd failure: marks subscription as failed (will be expired by ExpireSubscriptions worker)

  Retry schedule:
  - 1st retry: 24 hours after initial failure
  - 2nd retry: 48 hours after initial failure
  - 3rd retry: 72 hours after initial failure
  - After 3 failures: subscription is marked as failed and will expire
  """

  use Oban.Worker,
    queue: :payments,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Payments

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting failed payment retry processing...")

    retryable_subscriptions = Payments.list_retryable_subscriptions()
    Logger.info("Found #{length(retryable_subscriptions)} subscriptions to retry")

    results =
      Enum.map(retryable_subscriptions, fn subscription ->
        Logger.info("Retrying payment for subscription #{subscription.id} (attempt #{subscription.retry_count + 1}/3)")

        case Payments.process_renewal(subscription) do
          {:ok, result} ->
            Logger.info("Successfully initiated retry for subscription #{subscription.id}")
            {:ok, subscription.id, result}

          {:error, reason} ->
            Logger.error("Retry failed for subscription #{subscription.id}: #{inspect(reason)}")
            {:error, subscription.id, reason}
        end
      end)

    successful = Enum.count(results, fn {status, _, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _, _} -> status == :error end)

    Logger.info("Retry processing complete. Initiated: #{successful}, Failed: #{failed}")

    :ok
  end
end
