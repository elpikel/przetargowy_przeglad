defmodule PrzetargowyPrzeglad.TendersTest do
  use PrzetargowyPrzeglad.DataCase
  alias PrzetargowyPrzeglad.Tenders

  def tender_attrs(overrides \\ %{}) do
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

  describe "upsert_tender/1" do
    test "creates new tender" do
      assert {:ok, tender} = Tenders.upsert_tender(tender_attrs())
      assert tender.id != nil
    end

    test "updates existing tender" do
      attrs = tender_attrs(%{external_id: "same_id", title: "Original"})
      {:ok, original} = Tenders.upsert_tender(attrs)

      updated_attrs = %{attrs | title: "Updated"}
      {:ok, updated} = Tenders.upsert_tender(updated_attrs)

      assert updated.id == original.id
      assert updated.title == "Updated"
    end
  end

  describe "upsert_tenders/1" do
    test "bulk insert returns stats" do
      tenders = [
        tender_attrs(%{external_id: "1"}),
        tender_attrs(%{external_id: "2"}),
        tender_attrs(%{external_id: "3"})
      ]

      result = Tenders.upsert_tenders(tenders)

      assert result.inserted == 3
      assert result.failed == 0
    end
  end

  describe "get_top_for_newsletter/1" do
    test "returns top tenders by value" do
      # Create tenders with different values
      Tenders.upsert_tender(
        tender_attrs(%{external_id: "1", estimated_value: Decimal.new("500000")})
      )

      Tenders.upsert_tender(
        tender_attrs(%{external_id: "2", estimated_value: Decimal.new("100000")})
      )

      Tenders.upsert_tender(
        tender_attrs(%{external_id: "3", estimated_value: Decimal.new("300000")})
      )

      top = Tenders.get_top_for_newsletter(2)

      assert length(top) == 2
      assert Decimal.eq?(hd(top).estimated_value, Decimal.new("500000"))
    end

    test "excludes tenders with past deadline" do
      past = DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60, :second)
      Tenders.upsert_tender(tender_attrs(%{external_id: "past", submission_deadline: past}))

      top = Tenders.get_top_for_newsletter(10)

      refute Enum.any?(top, &(&1.external_id == "past"))
    end
  end

  describe "get_weekly_stats/0" do
    test "returns correct structure" do
      Tenders.upsert_tender(tender_attrs(%{external_id: "1", industry: "it"}))
      Tenders.upsert_tender(tender_attrs(%{external_id: "2", industry: "budowlana"}))

      stats = Tenders.get_weekly_stats()

      assert stats.total_count == 2
      assert is_map(stats.by_industry)
      assert is_list(stats.top_industries)
    end
  end
end
