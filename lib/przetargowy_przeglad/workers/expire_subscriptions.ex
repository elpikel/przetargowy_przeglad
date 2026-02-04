defmodule PrzetargowyPrzeglad.Workers.ExpireSubscriptions do
  @moduledoc """
  Oban worker that expires subscriptions that have passed their end date.

  ## Expiration Logic

  1. Finds active subscriptions past their period end date
  2. Marks them as expired
  3. Downgrades users to free plan

  This worker serves as a backup for Stripe webhooks (customer.subscription.deleted).
  It handles edge cases where:
  - Webhooks are delayed or fail to deliver
  - Subscriptions are cancelled at period end
  - Any subscription that wasn't properly cleaned up via webhooks
  """

  use Oban.Worker,
    queue: :payments,
    max_attempts: 3,
    unique: [period: 3600]

  alias PrzetargowyPrzeglad.Payments

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting subscription expiration processing...")

    expired_subscriptions = Payments.list_expired_subscriptions()
    Logger.info("Found #{length(expired_subscriptions)} expired subscriptions")

    results =
      Enum.map(expired_subscriptions, fn subscription ->
        Logger.info("Expiring subscription #{subscription.id} (user: #{subscription.user_id})")

        case Payments.expire_subscription(subscription) do
          {:ok, _subscription} ->
            Logger.info("Successfully expired subscription #{subscription.id}")
            {:ok, subscription.id}

          {:error, reason} ->
            Logger.error("Failed to expire subscription #{subscription.id}: #{inspect(reason)}")
            {:error, subscription.id, reason}
        end
      end)

    successful = Enum.count(results, fn result -> elem(result, 0) == :ok end)
    failed = Enum.count(results, fn result -> elem(result, 0) == :error end)

    Logger.info("Expiration processing complete. Expired: #{successful}, Failed: #{failed}")

    :ok
  end
end
