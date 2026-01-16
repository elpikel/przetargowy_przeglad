defmodule PrzetargowyPrzeglad.Workers.SendNewsletterWorker do
  use Oban.Worker,
    queue: :mailers,
    # Nie ponawiamy całej wysyłki
    max_attempts: 1

  alias PrzetargowyPrzeglad.Newsletters
  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Email.NewsletterEmail
  alias PrzetargowyPrzeglad.Mailer

  require Logger

  @batch_size 50
  @batch_delay 1_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    newsletter_id = args["newsletter_id"]

    newsletter =
      if newsletter_id do
        Newsletters.get_newsletter(newsletter_id)
      else
        Newsletters.get_ready_to_send()
      end

    case newsletter do
      nil ->
        Logger.info("SendNewsletterWorker: No newsletter ready to send")
        :ok

      %{status: "sent"} ->
        Logger.info("SendNewsletterWorker: Newsletter already sent")
        :ok

      newsletter ->
        send_newsletter(newsletter)
    end
  end

  defp send_newsletter(newsletter) do
    Logger.info("SendNewsletterWorker: Starting send for newsletter ##{newsletter.issue_number}")

    # Mark as sending
    {:ok, newsletter} = Newsletters.update_status(newsletter, "sending")

    # Get all confirmed subscribers
    subscribers = Subscribers.list_confirmed()
    total = length(subscribers)

    Logger.info("SendNewsletterWorker: Sending to #{total} subscribers")

    # Send in batches
    results =
      subscribers
      |> Enum.chunk_every(@batch_size)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {batch, batch_num} ->
        Logger.info("SendNewsletterWorker: Processing batch #{batch_num}")

        results =
          Enum.map(batch, fn subscriber ->
            send_to_subscriber(newsletter, subscriber)
          end)

        # Delay between batches
        Process.sleep(@batch_delay)

        results
      end)

    # Count results
    {successes, failures} =
      Enum.split_with(results, fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    success_count = length(successes)
    failure_count = length(failures)

    Logger.info("""
    SendNewsletterWorker: Completed
      Total: #{total}
      Success: #{success_count}
      Failed: #{failure_count}
    """)

    if failure_count > 0 do
      Logger.warning("SendNewsletterWorker: Failures: #{inspect(Enum.take(failures, 5))}")
    end

    # Mark as sent
    {:ok, _} = Newsletters.mark_sent(newsletter, success_count)

    :ok
  end

  defp send_to_subscriber(newsletter, subscriber) do
    email = NewsletterEmail.build(newsletter, subscriber)

    case Mailer.deliver(email) do
      {:ok, _} ->
        {:ok, subscriber.email}

      {:error, reason} ->
        Logger.warning(
          "SendNewsletterWorker: Failed to send to #{subscriber.email}: #{inspect(reason)}"
        )

        {:error, {subscriber.email, reason}}
    end
  end

  def enqueue(newsletter_id \\ nil) do
    args = if newsletter_id, do: %{"newsletter_id" => newsletter_id}, else: %{}

    args
    |> new()
    |> Oban.insert()
  end
end
