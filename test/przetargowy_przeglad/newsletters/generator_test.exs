defmodule PrzetargowyPrzeglad.Newsletter.GeneratorTest do
  use PrzetargowyPrzeglad.DataCase

  alias PrzetargowyPrzeglad.Newsletter.Generator
  alias PrzetargowyPrzeglad.Newsletter.Newsletter
  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Repo

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

  describe "generate/0" do
    test "creates a newsletter with correct attributes" do
      # Create some test tenders
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("500000")})
      )

      Tenders.upsert_tender(
        tender_attrs(%{external_id: "2", estimated_value: Decimal.new("300000")})
      )

      assert {:ok, newsletter} = Generator.generate()

      assert newsletter.issue_number == 1
      assert newsletter.status == "generated"
      assert newsletter.subject != nil
      assert newsletter.content_html != nil
      assert newsletter.content_text != nil
      assert newsletter.scheduled_at != nil
    end

    test "increments issue_number for each newsletter" do
      assert {:ok, first} = Generator.generate()
      assert {:ok, second} = Generator.generate()

      assert first.issue_number == 1
      assert second.issue_number == 2
    end

    test "includes featured tender ids" do
      {:ok, tender1} =
        Tenders.upsert_tender(
          tender_attrs(%{external_id: "1", estimated_value: Decimal.new("500000")})
        )

      {:ok, tender2} =
        Tenders.upsert_tender(
          tender_attrs(%{external_id: "2", estimated_value: Decimal.new("300000")})
        )

      assert {:ok, newsletter} = Generator.generate()

      assert tender1.id in newsletter.featured_tender_ids
      assert tender2.id in newsletter.featured_tender_ids
    end

    test "stores stats in newsletter" do
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("100000")})
      )

      assert {:ok, newsletter} = Generator.generate()

      assert is_map(newsletter.stats)
      assert Map.has_key?(newsletter.stats, :total_count)
    end

    test "schedules for next Monday at 8am" do
      assert {:ok, newsletter} = Generator.generate()

      # Should be a Monday
      assert Date.day_of_week(DateTime.to_date(newsletter.scheduled_at)) == 1
      # Should be at 8am
      assert newsletter.scheduled_at.hour == 8
      assert newsletter.scheduled_at.minute == 0
    end
  end

  describe "next_issue_number/0" do
    test "returns 1 when no newsletters exist" do
      assert Generator.next_issue_number() == 1
    end

    test "returns next number after existing newsletters" do
      %Newsletter{}
      |> Newsletter.changeset(%{
        issue_number: 5,
        subject: "Test",
        content_html: "<p>Test</p>"
      })
      |> Repo.insert!()

      assert Generator.next_issue_number() == 6
    end
  end

  describe "generated content" do
    test "html content contains required sections" do
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("500000")})
      )

      {:ok, newsletter} = Generator.generate()

      assert newsletter.content_html =~ "Przetargowy Przegląd"
      assert newsletter.content_html =~ "<!DOCTYPE html>"
    end

    test "text content contains required sections" do
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("500000")})
      )

      {:ok, newsletter} = Generator.generate()

      assert newsletter.content_text =~ "PRZETARGOWY PRZEGLĄD"
    end

    test "subject contains issue number and value summary" do
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("1000000")})
      )

      {:ok, newsletter} = Generator.generate()

      assert newsletter.subject =~ "#1"
      assert newsletter.subject =~ "zł"
    end
  end
end
