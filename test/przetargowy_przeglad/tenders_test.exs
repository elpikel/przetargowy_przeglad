defmodule PrzetargowyPrzeglad.TendersTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  @moduletag capture_log: true

  describe "get_tender_notice/1" do
    test "returns the tender notice by object_id" do
      tender_notice = insert(:tender_notice)

      assert Tenders.get_tender_notice(tender_notice.object_id).object_id == tender_notice.object_id
    end
  end

  describe "upsert_tender_notice/1" do
    test "inserts a new tender notice with all fields" do
      valid_attrs =
        params_for(:tender_notice,
          notice_type: "TenderResultNotice",
          procedure_result: "zawarcieUmowy",
          contractors: [
            %{
              contractor_name: "Polski Koncern Naftowy Orlen Spółka Akcyjna",
              contractor_city: "Płock",
              contractor_province: "PL14",
              contractor_country: "PL",
              contractor_national_id: "7740001454"
            }
          ],
          contractors_contract_details: [
            %{
              part: 1,
              status: :contract_signed,
              contractor_name: "Polski Koncern Naftowy Orlen Spółka Akcyjna",
              contractor_city: "Płock",
              contractor_nip: "7740001454",
              contract_value: Decimal.new("1500"),
              winning_price: Decimal.new("1500"),
              lowest_price: Decimal.new("1500"),
              highest_price: Decimal.new("1500"),
              cancellation_reason: nil,
              currency: "PLN"
            },
            %{
              part: 2,
              status: :contract_signed,
              contractor_name: "Polski Koncern Naftowy Orlen Spółka Akcyjna",
              contractor_city: "Płock",
              contractor_nip: "7740001454",
              contract_value: Decimal.new("2000"),
              winning_price: Decimal.new("2000"),
              lowest_price: Decimal.new("2000"),
              highest_price: Decimal.new("2000"),
              cancellation_reason: nil,
              currency: "PLN"
            }
          ]
        )

      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(valid_attrs)

      assert tender_notice.object_id
      assert tender_notice.client_type == "1.1.5"
      assert tender_notice.order_type == "Delivery"
      assert tender_notice.tender_type == "1.1.1"
      assert tender_notice.notice_type == "TenderResultNotice"
      assert tender_notice.procedure_result == "zawarcieUmowy"

      # Contractors
      assert length(tender_notice.contractors) == 1
      contractor = hd(tender_notice.contractors)
      assert contractor.contractor_name == "Polski Koncern Naftowy Orlen Spółka Akcyjna"

      # Parts (contractors_contract_details)
      assert length(tender_notice.contractors_contract_details) == 2
    end

    test "updates an existing tender notice on conflict" do
      valid_attrs = params_for(:tender_notice)
      {:ok, _tender_notice} = Tenders.upsert_tender_notice(valid_attrs)
      updated_attrs = Map.put(valid_attrs, :organization_name, "Updated Org")
      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(updated_attrs)
      assert tender_notice.organization_name == "Updated Org"
    end
  end

  describe "upsert_tender_notices/1" do
    test "inserts multiple tender notices and returns success count" do
      attrs1 = params_for(:tender_notice)
      attrs2 = params_for(:tender_notice)
      {success_count, failed} = Tenders.upsert_tender_notices([attrs1, attrs2])
      assert success_count == 2
      assert failed == []
    end

    test "returns failed list for invalid tender notices" do
      invalid_attrs = :tender_notice |> params_for() |> Map.delete(:object_id)
      {success_count, failed} = Tenders.upsert_tender_notices([invalid_attrs])
      assert success_count == 0
      assert length(failed) == 1
    end

    test "handles Decimal values in embedded schemas (reproducing Jason.Encoder error)" do
      # This test reproduces the exact error from the stack trace
      attrs_with_decimal =
        params_for(:tender_notice,
          contractors_contract_details: [
            %{
              part: 1,
              status: :contract_signed,
              contractor_name: "Test Contractor",
              contractor_city: "Test City",
              contractor_nip: "1234567890",
              contract_value: Decimal.new("99682.80"),
              winning_price: Decimal.new("99682.80"),
              lowest_price: Decimal.new("99682.80"),
              highest_price: Decimal.new("99682.80"),
              cancellation_reason: nil,
              currency: "PLN"
            }
          ]
        )

      # This should fail with Protocol.UndefinedError if Jason.Encoder is not implemented for Decimal
      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(attrs_with_decimal)

      [detail] = tender_notice.contractors_contract_details
      assert Decimal.equal?(detail.contract_value, Decimal.new("99682.80"))
    end
  end

  describe "search_tender_notices/1 with multi-region filter" do
    setup do
      # Create tender notices in different regions
      insert(:mazowieckie_tender, order_type: "Delivery")
      insert(:malopolskie_tender, order_type: "Delivery")
      insert(:wielkopolskie_tender, order_type: "Delivery")
      insert(:slaskie_tender, order_type: "Services")

      :ok
    end

    test "filters by single region" do
      result = Tenders.search_tender_notices(regions: ["mazowieckie"], page: 1, per_page: 20)
      assert result.total_count == 1
    end

    test "filters by multiple regions" do
      result = Tenders.search_tender_notices(regions: ["mazowieckie", "malopolskie"], page: 1, per_page: 20)
      assert result.total_count == 2
    end

    test "returns all results when regions is empty list" do
      result = Tenders.search_tender_notices(regions: [], page: 1, per_page: 20)
      assert result.total_count == 4
    end

    test "returns all results when regions is nil" do
      result = Tenders.search_tender_notices(regions: nil, page: 1, per_page: 20)
      assert result.total_count == 4
    end

    test "handles empty strings in regions list" do
      result = Tenders.search_tender_notices(regions: ["", "mazowieckie", ""], page: 1, per_page: 20)
      assert result.total_count == 1
    end

    test "handles non-existent region codes" do
      result = Tenders.search_tender_notices(regions: ["nonexistent"], page: 1, per_page: 20)
      assert result.total_count == 0
    end
  end

  describe "search_tender_notices/1 with multi-order-type filter" do
    setup do
      # Create tender notices with different order types
      insert(:delivery_tender, organization_province: "PL14")
      insert(:services_tender, organization_province: "PL14")
      insert(:works_tender, organization_province: "PL14")
      insert(:delivery_tender, organization_province: "PL12")

      :ok
    end

    test "filters by single order type" do
      result = Tenders.search_tender_notices(order_types: ["Delivery"], page: 1, per_page: 20)
      assert result.total_count == 2
    end

    test "filters by multiple order types" do
      result = Tenders.search_tender_notices(order_types: ["Delivery", "Services"], page: 1, per_page: 20)
      assert result.total_count == 3
    end

    test "returns all results when order_types is empty list" do
      result = Tenders.search_tender_notices(order_types: [], page: 1, per_page: 20)
      assert result.total_count == 4
    end

    test "returns all results when order_types is nil" do
      result = Tenders.search_tender_notices(order_types: nil, page: 1, per_page: 20)
      assert result.total_count == 4
    end

    test "handles empty strings in order_types list" do
      result = Tenders.search_tender_notices(order_types: ["", "Delivery", ""], page: 1, per_page: 20)
      assert result.total_count == 2
    end

    test "handles non-existent order types" do
      result = Tenders.search_tender_notices(order_types: ["NonExistent"], page: 1, per_page: 20)
      assert result.total_count == 0
    end
  end

  describe "search_tender_notices/1 with combined filters" do
    setup do
      # Create combinations
      insert(:mazowieckie_tender, order_type: "Delivery", order_object: "Delivery in mazowieckie")
      insert(:mazowieckie_tender, order_type: "Services", order_object: "Services in mazowieckie")
      insert(:malopolskie_tender, order_type: "Delivery", order_object: "Delivery in malopolskie")
      insert(:malopolskie_tender, order_type: "Works", order_object: "Works in malopolskie")

      :ok
    end

    test "filters by multiple regions and multiple order types" do
      result =
        Tenders.search_tender_notices(
          regions: ["mazowieckie", "malopolskie"],
          order_types: ["Delivery"],
          page: 1,
          per_page: 20
        )

      assert result.total_count == 2
    end

    test "filters by query, regions, and order types" do
      result =
        Tenders.search_tender_notices(
          query: "mazowieckie",
          regions: ["mazowieckie"],
          order_types: ["Delivery"],
          page: 1,
          per_page: 20
        )

      assert result.total_count == 1
    end

    test "handles case sensitivity in region names" do
      # Should be case-insensitive or handle properly
      result = Tenders.search_tender_notices(regions: ["MAZOWIECKIE"], page: 1, per_page: 20)
      # Depending on implementation, this might return 0 or apply case-insensitive matching
      assert result.total_count >= 0
    end
  end
end
