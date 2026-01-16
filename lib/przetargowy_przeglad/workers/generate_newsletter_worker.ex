defmodule PrzetargowyPrzeglad.Workers.GenerateNewsletterWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias PrzetargowyPrzeglad.Newsletters

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("GenerateNewsletterWorker: Starting generation")

    case Newsletters.generate_weekly() do
      {:ok, newsletter} ->
        Logger.info("GenerateNewsletterWorker: Created newsletter ##{newsletter.issue_number}")
        :ok

      {:error, changeset} ->
        Logger.error("GenerateNewsletterWorker: Failed - #{inspect(changeset.errors)}")
        {:error, "Generation failed"}
    end
  end

  def enqueue do
    %{}
    |> new()
    |> Oban.insert()
  end
end
