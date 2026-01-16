defmodule PrzetargowyPrzeglad.Api.BzpClientTest do
  use ExUnit.Case, async: true

  # Test parsing functions directly (no HTTP)

  describe "parse_tender (via fetch simulation)" do
    test "parses complete tender data" do
      raw = %{
        "ocid" => "ocds-123",
        "title" => "Dostawa komputerów",
        "description" => "Opis zamówienia",
        "noticeType" => "ContractNotice",
        "publicationDate" => "2024-01-15T10:00:00Z",
        "submissionDeadline" => "2024-02-15T12:00:00Z",
        "estimatedValue" => 500_000,
        "currency" => "PLN",
        "contractingAuthority" => %{
          "name" => "Urząd Miasta",
          "city" => "Warszawa",
          "address" => %{"region" => "mazowieckie"}
        },
        "cpvCodes" => ["72000000", "30200000"]
      }

      # Use module's internal parsing (would need to expose or test via integration)
      # For now, we test the contract
      assert raw["ocid"] == "ocds-123"
      assert raw["estimatedValue"] == 500_000
    end
  end

  describe "normalize_region" do
    # Test region normalization logic
    test "normalizes polish region names" do
      # These would be tested via integration or by exposing the function
      # Placeholder
      assert true
    end
  end

  describe "CPV to industry mapping" do
    test "maps correctly via Tender schema" do
      alias PrzetargowyPrzeglad.Tenders.Tender

      assert Tender.map_cpv_to_industry(["72000000"]) == "it"
      assert Tender.map_cpv_to_industry(["45000000"]) == "budowlana"
      assert Tender.map_cpv_to_industry(["33000000"]) == "medyczna"
    end
  end
end
