defmodule PrzetargowyPrzeglad.Tenders.TenderTest do
  use PrzetargowyPrzeglad.DataCase
  alias PrzetargowyPrzeglad.Tenders.Tender

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{
        external_id: "123",
        source: "bzp",
        title: "Test tender"
      }

      changeset = Tender.changeset(%Tender{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = Tender.changeset(%Tender{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).external_id
      assert "can't be blank" in errors_on(changeset).source
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid source rejected" do
      attrs = %{external_id: "123", source: "invalid", title: "Test"}
      changeset = Tender.changeset(%Tender{}, attrs)
      refute changeset.valid?
    end
  end

  describe "map_cpv_to_industry/1" do
    test "maps IT codes" do
      assert Tender.map_cpv_to_industry(["72000000"]) == "it"
      assert Tender.map_cpv_to_industry(["48000000"]) == "it"
    end

    test "maps construction codes" do
      assert Tender.map_cpv_to_industry(["45000000"]) == "budowlana"
    end

    test "maps medical codes" do
      assert Tender.map_cpv_to_industry(["33000000"]) == "medyczna"
    end

    test "unknown codes return inne" do
      assert Tender.map_cpv_to_industry(["99999999"]) == "inne"
    end

    test "empty list returns inne" do
      assert Tender.map_cpv_to_industry([]) == "inne"
    end
  end
end
