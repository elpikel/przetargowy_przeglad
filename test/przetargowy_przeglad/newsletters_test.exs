defmodule PrzetargowyPrzeglad.NewslettersTest do
  use PrzetargowyPrzeglad.DataCase

  alias PrzetargowyPrzeglad.Newsletters
  alias PrzetargowyPrzeglad.Newsletter.Newsletter
  alias PrzetargowyPrzeglad.Tenders

  defp newsletter_attrs(overrides) do
    Map.merge(
      %{
        issue_number: System.unique_integer([:positive]),
        subject: "Test Newsletter",
        content_html: "<p>Test content</p>",
        content_text: "Test content",
        status: "draft"
      },
      overrides
    )
  end

  defp create_newsletter(overrides) do
    %Newsletter{}
    |> Newsletter.changeset(newsletter_attrs(overrides))
    |> Repo.insert!()
  end

  defp tender_attrs(overrides) do
    Map.merge(
      %{
        external_id: "ext_#{System.unique_integer()}",
        source: "bzp",
        title: "Test tender",
        estimated_value: Decimal.new("100000"),
        publication_date: DateTime.utc_now(),
        submission_deadline: DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)
      },
      overrides
    )
  end

  describe "generate_weekly/0" do
    test "creates a newsletter" do
      Tenders.upsert_tender(tender_attrs(%{external_id: "1"}))

      assert {:ok, newsletter} = Newsletters.generate_weekly()
      assert newsletter.status == "generated"
    end
  end

  describe "get_newsletter/1" do
    test "returns newsletter by id" do
      newsletter = create_newsletter(%{issue_number: 1})

      assert fetched = Newsletters.get_newsletter(newsletter.id)
      assert fetched.id == newsletter.id
    end

    test "returns nil for non-existent id" do
      assert Newsletters.get_newsletter(-1) == nil
    end
  end

  describe "get_by_issue/1" do
    test "returns newsletter by issue number" do
      newsletter = create_newsletter(%{issue_number: 42})

      assert fetched = Newsletters.get_by_issue(42)
      assert fetched.id == newsletter.id
    end

    test "returns nil for non-existent issue number" do
      assert Newsletters.get_by_issue(999) == nil
    end
  end

  describe "get_latest/0" do
    test "returns the newsletter with highest issue number" do
      create_newsletter(%{issue_number: 1})
      create_newsletter(%{issue_number: 3})
      create_newsletter(%{issue_number: 2})

      latest = Newsletters.get_latest()
      assert latest.issue_number == 3
    end

    test "returns nil when no newsletters exist" do
      assert Newsletters.get_latest() == nil
    end
  end

  describe "get_ready_to_send/0" do
    test "returns generated newsletter" do
      create_newsletter(%{issue_number: 1, status: "draft"})
      generated = create_newsletter(%{issue_number: 2, status: "generated"})
      create_newsletter(%{issue_number: 3, status: "sent"})

      ready = Newsletters.get_ready_to_send()
      assert ready.id == generated.id
    end

    test "returns latest generated when multiple exist" do
      create_newsletter(%{issue_number: 1, status: "generated"})
      latest_generated = create_newsletter(%{issue_number: 2, status: "generated"})

      ready = Newsletters.get_ready_to_send()
      assert ready.id == latest_generated.id
    end

    test "returns nil when no generated newsletters exist" do
      create_newsletter(%{issue_number: 1, status: "draft"})
      create_newsletter(%{issue_number: 2, status: "sent"})

      assert Newsletters.get_ready_to_send() == nil
    end
  end

  describe "list_newsletters/1" do
    test "returns newsletters ordered by issue number desc" do
      create_newsletter(%{issue_number: 1})
      create_newsletter(%{issue_number: 3})
      create_newsletter(%{issue_number: 2})

      newsletters = Newsletters.list_newsletters()

      assert [first, second, third] = newsletters
      assert first.issue_number == 3
      assert second.issue_number == 2
      assert third.issue_number == 1
    end

    test "filters by status" do
      create_newsletter(%{issue_number: 1, status: "draft"})
      create_newsletter(%{issue_number: 2, status: "sent"})
      create_newsletter(%{issue_number: 3, status: "sent"})

      sent = Newsletters.list_newsletters(status: "sent")

      assert length(sent) == 2
      assert Enum.all?(sent, &(&1.status == "sent"))
    end

    test "respects limit option" do
      for i <- 1..5, do: create_newsletter(%{issue_number: i})

      limited = Newsletters.list_newsletters(limit: 2)

      assert length(limited) == 2
    end

    test "defaults to limit of 20" do
      for i <- 1..25, do: create_newsletter(%{issue_number: i})

      newsletters = Newsletters.list_newsletters()

      assert length(newsletters) == 20
    end
  end

  describe "update_status/2" do
    test "updates newsletter status" do
      newsletter = create_newsletter(%{issue_number: 1, status: "draft"})

      assert {:ok, updated} = Newsletters.update_status(newsletter, "generated")
      assert updated.status == "generated"
    end

    test "returns error for invalid status" do
      newsletter = create_newsletter(%{issue_number: 1, status: "draft"})

      assert {:error, changeset} = Newsletters.update_status(newsletter, "invalid")
      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "mark_sent/2" do
    test "marks newsletter as sent with recipients count" do
      newsletter = create_newsletter(%{issue_number: 1, status: "sending"})

      assert {:ok, sent} = Newsletters.mark_sent(newsletter, 150)
      assert sent.status == "sent"
      assert sent.recipients_count == 150
      assert sent.sent_at != nil
    end
  end
end
