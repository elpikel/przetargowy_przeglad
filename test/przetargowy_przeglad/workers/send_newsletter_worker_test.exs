defmodule PrzetargowyPrzeglad.Workers.SendNewsletterWorkerTest do
  use PrzetargowyPrzeglad.DataCase
  use Oban.Testing, repo: PrzetargowyPrzeglad.Repo

  import Swoosh.TestAssertions

  alias PrzetargowyPrzeglad.Workers.SendNewsletterWorker
  alias PrzetargowyPrzeglad.Newsletter.Newsletter
  alias PrzetargowyPrzeglad.Subscribers
  alias PrzetargowyPrzeglad.Newsletters

  defp create_newsletter(attrs) do
    default_attrs = %{
      issue_number: System.unique_integer([:positive]),
      subject: "Test Newsletter",
      content_html: "<p>Hello{{subscriber_name_greeting}}!</p>",
      content_text: "Hello{{subscriber_name_greeting}}!",
      status: "generated"
    }

    %Newsletter{}
    |> Newsletter.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp create_confirmed_subscriber(email) do
    {:ok, subscriber} = Subscribers.subscribe(%{email: email})
    Subscribers.confirm_subscription(subscriber.confirmation_token)
  end

  describe "perform/1" do
    test "returns ok when no newsletter is ready to send" do
      assert :ok = perform_job(SendNewsletterWorker, %{})
    end

    test "returns ok when newsletter is already sent" do
      newsletter = create_newsletter(%{status: "sent"})

      assert :ok = perform_job(SendNewsletterWorker, %{"newsletter_id" => newsletter.id})
    end

    test "sends newsletter to confirmed subscribers" do
      newsletter = create_newsletter(%{status: "generated"})
      {:ok, _} = create_confirmed_subscriber("user1@example.com")
      {:ok, _} = create_confirmed_subscriber("user2@example.com")

      assert :ok = perform_job(SendNewsletterWorker, %{"newsletter_id" => newsletter.id})

      assert_email_sent(to: [{"", "user1@example.com"}])
      assert_email_sent(to: [{"", "user2@example.com"}])
    end

    test "marks newsletter as sent after completion" do
      newsletter = create_newsletter(%{status: "generated"})
      {:ok, _} = create_confirmed_subscriber("user@example.com")

      assert :ok = perform_job(SendNewsletterWorker, %{"newsletter_id" => newsletter.id})

      updated = Newsletters.get_newsletter(newsletter.id)
      assert updated.status == "sent"
      assert updated.recipients_count == 1
      assert updated.sent_at != nil
    end

    test "finds ready newsletter when no id provided" do
      create_newsletter(%{issue_number: 1, status: "generated"})
      {:ok, _} = create_confirmed_subscriber("user@example.com")

      assert :ok = perform_job(SendNewsletterWorker, %{})

      assert_email_sent(to: [{"", "user@example.com"}])
    end

    test "does not send newsletter to unconfirmed subscribers" do
      newsletter = create_newsletter(%{status: "generated"})
      # Create but don't confirm
      Subscribers.subscribe(%{email: "unconfirmed@example.com"})

      assert :ok = perform_job(SendNewsletterWorker, %{"newsletter_id" => newsletter.id})

      # Newsletter was marked as sent with 0 recipients (no confirmed subscribers)
      updated = Newsletters.get_newsletter(newsletter.id)
      assert updated.status == "sent"
      assert updated.recipients_count == 0
    end
  end

  describe "enqueue/0" do
    test "creates a job without newsletter_id" do
      assert {:ok, job} = SendNewsletterWorker.enqueue()
      assert job.queue == "mailers"
      assert job.args == %{}
    end
  end

  describe "enqueue/1" do
    test "creates a job with newsletter_id" do
      assert {:ok, job} = SendNewsletterWorker.enqueue(123)
      assert job.args == %{"newsletter_id" => 123}
    end

    test "creates a job with nil newsletter_id" do
      assert {:ok, job} = SendNewsletterWorker.enqueue(nil)
      assert job.args == %{}
    end

    test "job has max_attempts of 1" do
      assert {:ok, job} = SendNewsletterWorker.enqueue()
      assert job.max_attempts == 1
    end
  end
end
