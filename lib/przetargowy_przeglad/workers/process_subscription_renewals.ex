defmodule PrzetargowyPrzeglad.Workers.ProcessSubscriptionRenewals do
  @moduledoc """
  Oban worker that processes subscription renewals.
  Runs daily to charge active subscriptions that are due for renewal.

  ## Renewal Logic

  1. Finds subscriptions expiring in the next 24 hours
  2. Skips subscriptions marked for cancellation at period end
  3. Charges the saved card via Tpay recurring payment
  4. On success: extends subscription for another month
  5. On failure: increments retry count (webhook will handle completion)
  """

  use Oban.Worker,
    queue: :payments,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Payments

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting subscription renewal processing...")

    subscriptions = Payments.list_subscriptions_due_for_renewal(24)
    Logger.info("Found #{length(subscriptions)} subscriptions due for renewal")

    results =
      Enum.map(subscriptions, fn subscription ->
        Logger.info("Processing renewal for subscription #{subscription.id} (user: #{subscription.user_id})")

        case Payments.process_renewal(subscription) do
          {:ok, result} ->
            Logger.info("Successfully initiated renewal for subscription #{subscription.id}")
            {:ok, subscription.id, result}

          {:error, reason} ->
            Logger.error("Failed to renew subscription #{subscription.id}: #{inspect(reason)}")
            {:error, subscription.id, reason}
        end
      end)

    successful = Enum.count(results, fn {status, _, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _, _} -> status == :error end)

    Logger.info("Renewal processing complete. Successful: #{successful}, Failed: #{failed}")

    :ok
  end
end
