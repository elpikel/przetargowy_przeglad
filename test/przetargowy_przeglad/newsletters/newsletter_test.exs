defmodule PrzetargowyPrzeglad.Newsletter.NewsletterTest do
  use PrzetargowyPrzeglad.DataCase

  alias PrzetargowyPrzeglad.Newsletter.Newsletter

  describe "changeset/2" do
    test "valid with required fields" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          issue_number: 1,
          subject: "Test Subject",
          content_html: "<p>Test content</p>"
        })

      assert changeset.valid?
    end

    test "invalid without issue_number" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          subject: "Test Subject",
          content_html: "<p>Test content</p>"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).issue_number
    end

    test "invalid without subject" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          issue_number: 1,
          content_html: "<p>Test content</p>"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).subject
    end

    test "invalid without content_html" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          issue_number: 1,
          subject: "Test Subject"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content_html
    end

    test "valid status values are accepted" do
      for status <- ~w(draft generated sending sent) do
        changeset =
          Newsletter.changeset(%Newsletter{}, %{
            issue_number: 1,
            subject: "Test",
            content_html: "<p>Test</p>",
            status: status
          })

        assert changeset.valid?, "Expected status '#{status}' to be valid"
      end
    end

    test "invalid status is rejected" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          issue_number: 1,
          subject: "Test",
          content_html: "<p>Test</p>",
          status: "invalid_status"
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "casts optional fields" do
      changeset =
        Newsletter.changeset(%Newsletter{}, %{
          issue_number: 1,
          subject: "Test",
          content_html: "<p>Test</p>",
          content_text: "Test text",
          stats: %{total: 10},
          featured_tender_ids: [1, 2, 3],
          recipients_count: 100,
          opens_count: 50,
          clicks_count: 25
        })

      assert changeset.valid?
      assert get_change(changeset, :content_text) == "Test text"
      assert get_change(changeset, :stats) == %{total: 10}
      assert get_change(changeset, :featured_tender_ids) == [1, 2, 3]
      assert get_change(changeset, :recipients_count) == 100
      assert get_change(changeset, :opens_count) == 50
      assert get_change(changeset, :clicks_count) == 25
    end

    test "unique constraint on issue_number" do
      {:ok, _} =
        %Newsletter{}
        |> Newsletter.changeset(%{
          issue_number: 1,
          subject: "First",
          content_html: "<p>First</p>"
        })
        |> Repo.insert()

      {:error, changeset} =
        %Newsletter{}
        |> Newsletter.changeset(%{
          issue_number: 1,
          subject: "Second",
          content_html: "<p>Second</p>"
        })
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).issue_number
    end
  end

  describe "mark_generated/1" do
    test "sets status to generated" do
      newsletter = %Newsletter{status: "draft"}
      changeset = Newsletter.mark_generated(newsletter)

      assert get_change(changeset, :status) == "generated"
    end
  end

  describe "mark_sending/1" do
    test "sets status to sending" do
      newsletter = %Newsletter{status: "generated"}
      changeset = Newsletter.mark_sending(newsletter)

      assert get_change(changeset, :status) == "sending"
    end
  end

  describe "mark_sent/2" do
    test "sets status to sent with recipients count and sent_at" do
      newsletter = %Newsletter{status: "sending"}
      changeset = Newsletter.mark_sent(newsletter, 150)

      assert get_change(changeset, :status) == "sent"
      assert get_change(changeset, :recipients_count) == 150
      assert get_change(changeset, :sent_at) != nil
    end

    test "sent_at is truncated to seconds" do
      newsletter = %Newsletter{status: "sending"}
      changeset = Newsletter.mark_sent(newsletter, 100)

      sent_at = get_change(changeset, :sent_at)
      assert sent_at.microsecond == {0, 0}
    end
  end

  describe "statuses/0" do
    test "returns list of valid statuses" do
      assert Newsletter.statuses() == ~w(draft generated sending sent)
    end
  end

  describe "schema defaults" do
    test "status defaults to draft" do
      newsletter = %Newsletter{}
      assert newsletter.status == "draft"
    end

    test "stats defaults to empty map" do
      newsletter = %Newsletter{}
      assert newsletter.stats == %{}
    end

    test "featured_tender_ids defaults to empty list" do
      newsletter = %Newsletter{}
      assert newsletter.featured_tender_ids == []
    end

    test "counts default to 0" do
      newsletter = %Newsletter{}
      assert newsletter.recipients_count == 0
      assert newsletter.opens_count == 0
      assert newsletter.clicks_count == 0
    end
  end
end
