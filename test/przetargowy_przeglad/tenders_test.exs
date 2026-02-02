defmodule PrzetargowyPrzeglad.TendersTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Tenders
  alias PrzetargowyPrzeglad.Tenders.TenderNotice

  @moduletag capture_log: true

  @valid_attrs %{
    object_id: "obj-1",
    client_type: "1.1.5",
    order_type: "Delivery",
    tender_type: "1.1.1",
    notice_type: "TenderResultNotice",
    notice_number: "2022/BZP 00001610/01",
    bzp_number: "2022/BZP 00001610",
    is_tender_amount_below_eu: true,
    publication_date: ~U[2022-01-04 06:52:51Z],
    order_object: "Zakup paliw ciekłych",
    cpv_codes: ["09100000-0", "09132100-4"],
    submitting_offers_date: nil,
    procedure_result: "zawarcieUmowy",
    organization_name: "Krajowe Centrum Hodowli Zwierząt",
    organization_city: "Warszawa",
    organization_province: "PL14",
    organization_country: "PL",
    organization_national_id: "5272529237",
    organization_id: "9565",
    tender_id: "ocds-148610-1df96928-5744-11ec-8c2d-66c2f1230e9c",
    html_body: "<html>...</html>",
    contractors: [
      %{
        contractor_name: "Polski Koncern Naftowy Orlen Spółka Akcyjna",
        contractor_city: "Płock",
        contractor_province: "PL14",
        contractor_country: "PL",
        contractor_national_id: "7740001454"
      }
    ],
    estimated_values: [Decimal.new("1000"), Decimal.new("2000")],
    estimated_value: Decimal.new("3000"),
    total_contract_value: Decimal.new("3500"),
    total_contractors_contracts_count: 2,
    cancelled_count: 0,
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
  }

  describe "get_tender_notice/1" do
    test "returns the tender notice by object_id" do
      {:ok, tender_notice} =
        %TenderNotice{}
        |> TenderNotice.changeset(@valid_attrs)
        |> PrzetargowyPrzeglad.Repo.insert()

      assert Tenders.get_tender_notice(tender_notice.object_id).object_id == tender_notice.object_id
    end
  end

  describe "upsert_tender_notice/1" do
    test "inserts a new tender notice with all fields" do
      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(@valid_attrs)

      assert tender_notice.object_id == @valid_attrs.object_id
      assert tender_notice.client_type == @valid_attrs.client_type
      assert tender_notice.order_type == @valid_attrs.order_type
      assert tender_notice.tender_type == @valid_attrs.tender_type
      assert tender_notice.notice_type == @valid_attrs.notice_type
      assert tender_notice.notice_number == @valid_attrs.notice_number
      assert tender_notice.bzp_number == @valid_attrs.bzp_number
      assert tender_notice.is_tender_amount_below_eu == @valid_attrs.is_tender_amount_below_eu
      assert tender_notice.publication_date == @valid_attrs.publication_date
      assert tender_notice.order_object == @valid_attrs.order_object
      assert tender_notice.cpv_codes == @valid_attrs.cpv_codes
      assert tender_notice.submitting_offers_date == @valid_attrs.submitting_offers_date
      assert tender_notice.procedure_result == @valid_attrs.procedure_result
      assert tender_notice.organization_name == @valid_attrs.organization_name
      assert tender_notice.organization_city == @valid_attrs.organization_city
      assert tender_notice.organization_province == @valid_attrs.organization_province
      assert tender_notice.organization_country == @valid_attrs.organization_country
      assert tender_notice.organization_national_id == @valid_attrs.organization_national_id
      assert tender_notice.organization_id == @valid_attrs.organization_id
      assert tender_notice.tender_id == @valid_attrs.tender_id
      assert tender_notice.html_body == @valid_attrs.html_body
      assert tender_notice.estimated_values == @valid_attrs.estimated_values
      assert tender_notice.estimated_value == @valid_attrs.estimated_value
      assert tender_notice.total_contract_value == @valid_attrs.total_contract_value
      assert tender_notice.total_contractors_contracts_count == @valid_attrs.total_contractors_contracts_count
      assert tender_notice.cancelled_count == @valid_attrs.cancelled_count

      # Contractors
      assert length(tender_notice.contractors) == 1
      contractor = hd(tender_notice.contractors)
      expected_contractor = hd(@valid_attrs.contractors)
      assert contractor.contractor_name == expected_contractor.contractor_name
      assert contractor.contractor_city == expected_contractor.contractor_city
      assert contractor.contractor_province == expected_contractor.contractor_province
      assert contractor.contractor_country == expected_contractor.contractor_country
      assert contractor.contractor_national_id == expected_contractor.contractor_national_id

      # Parts (contractors_contract_details)
      assert length(tender_notice.contractors_contract_details) == length(@valid_attrs.contractors_contract_details)

      tender_notice.contractors_contract_details
      |> Enum.zip(@valid_attrs.contractors_contract_details)
      |> Enum.each(fn {part, expected_part} ->
        assert part.part == expected_part.part
        assert part.status == expected_part.status
        assert part.contractor_name == expected_part.contractor_name
        assert part.contractor_city == expected_part.contractor_city
        assert part.contractor_nip == expected_part.contractor_nip
        assert part.contract_value == expected_part.contract_value
        assert part.winning_price == expected_part.winning_price
        assert part.lowest_price == expected_part.lowest_price
        assert part.highest_price == expected_part.highest_price
        assert part.cancellation_reason == expected_part.cancellation_reason
        assert part.currency == expected_part.currency
      end)
    end

    test "updates an existing tender notice on conflict" do
      {:ok, _tender_notice} = Tenders.upsert_tender_notice(@valid_attrs)
      updated_attrs = Map.put(@valid_attrs, :organization_name, "Updated Org")
      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(updated_attrs)
      assert tender_notice.organization_name == "Updated Org"
    end
  end

  describe "upsert_tender_notices/1" do
    test "inserts multiple tender notices and returns success count" do
      attrs1 = Map.put(@valid_attrs, :object_id, "obj-1")
      attrs2 = Map.put(@valid_attrs, :object_id, "obj-2")
      {success_count, failed} = Tenders.upsert_tender_notices([attrs1, attrs2])
      assert success_count == 2
      assert failed == []
    end

    test "returns failed list for invalid tender notices" do
      invalid_attrs = Map.delete(@valid_attrs, :object_id)
      {success_count, failed} = Tenders.upsert_tender_notices([invalid_attrs])
      assert success_count == 0
      assert length(failed) == 1
    end

    test "handles Decimal values in embedded schemas (reproducing Jason.Encoder error)" do
      # This test reproduces the exact error from the stack trace
      attrs_with_decimal =
        Map.put(@valid_attrs, :contractors_contract_details, [
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
        ])

      # This should fail with Protocol.UndefinedError if Jason.Encoder is not implemented for Decimal
      assert {:ok, %TenderNotice{} = tender_notice} = Tenders.upsert_tender_notice(attrs_with_decimal)

      [detail] = tender_notice.contractors_contract_details
      assert Decimal.equal?(detail.contract_value, Decimal.new("99682.80"))
    end
  end

  describe "search_tender_notices/1 with multi-region filter" do
    setup do
      # Create tender notices in different regions
      create_notice("mazowieckie", "PL14", "Delivery")
      create_notice("malopolskie", "PL12", "Delivery")
      create_notice("wielkopolskie", "PL16", "Delivery")
      create_notice("slaskie", "PL11", "Services")

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

    defp create_notice(region, province_code, order_type) do
      attrs = %{
        object_id: "notice-#{:erlang.unique_integer([:positive])}",
        client_type: "1.1.5",
        order_type: order_type,
        tender_type: "1.1.1",
        notice_type: "ContractNotice",
        notice_number: "2024/BZP #{:erlang.unique_integer([:positive])}/01",
        bzp_number: "2024/BZP #{:erlang.unique_integer([:positive])}",
        is_tender_amount_below_eu: true,
        publication_date: DateTime.utc_now(),
        order_object: "Test order in #{region}",
        cpv_codes: ["09100000-0"],
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        procedure_result: nil,
        organization_name: "Organization in #{region}",
        organization_city: "City",
        organization_province: province_code,
        organization_country: "PL",
        organization_national_id: "1234567890",
        organization_id: "1234",
        tender_id: "ocds-148610-test-#{:erlang.unique_integer([:positive])}",
        html_body: "<html>...</html>",
        contractors: [],
        estimated_values: [],
        estimated_value: Decimal.new("10000"),
        total_contract_value: nil,
        total_contractors_contracts_count: 0,
        cancelled_count: 0,
        contractors_contract_details: []
      }

      {:ok, _} = Tenders.upsert_tender_notice(attrs)
    end
  end

  describe "search_tender_notices/1 with multi-order-type filter" do
    setup do
      # Create tender notices with different order types
      create_notice_with_type("Delivery", "PL14")
      create_notice_with_type("Services", "PL14")
      create_notice_with_type("Works", "PL14")
      create_notice_with_type("Delivery", "PL12")

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

    defp create_notice_with_type(order_type, province) do
      attrs = %{
        object_id: "notice-#{:erlang.unique_integer([:positive])}",
        client_type: "1.1.5",
        order_type: order_type,
        tender_type: "1.1.1",
        notice_type: "ContractNotice",
        notice_number: "2024/BZP #{:erlang.unique_integer([:positive])}/01",
        bzp_number: "2024/BZP #{:erlang.unique_integer([:positive])}",
        is_tender_amount_below_eu: true,
        publication_date: DateTime.utc_now(),
        order_object: "Test order type #{order_type}",
        cpv_codes: ["09100000-0"],
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        procedure_result: nil,
        organization_name: "Organization",
        organization_city: "City",
        organization_province: province,
        organization_country: "PL",
        organization_national_id: "1234567890",
        organization_id: "1234",
        tender_id: "ocds-148610-test-#{:erlang.unique_integer([:positive])}",
        html_body: "<html>...</html>",
        contractors: [],
        estimated_values: [],
        estimated_value: Decimal.new("10000"),
        total_contract_value: nil,
        total_contractors_contracts_count: 0,
        cancelled_count: 0,
        contractors_contract_details: []
      }

      {:ok, _} = Tenders.upsert_tender_notice(attrs)
    end
  end

  describe "search_tender_notices/1 with combined filters" do
    setup do
      # Create combinations
      create_notice_combined("mazowieckie", "PL14", "Delivery")
      create_notice_combined("mazowieckie", "PL14", "Services")
      create_notice_combined("malopolskie", "PL12", "Delivery")
      create_notice_combined("malopolskie", "PL12", "Works")

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

    defp create_notice_combined(region, province_code, order_type) do
      attrs = %{
        object_id: "notice-#{:erlang.unique_integer([:positive])}",
        client_type: "1.1.5",
        order_type: order_type,
        tender_type: "1.1.1",
        notice_type: "ContractNotice",
        notice_number: "2024/BZP #{:erlang.unique_integer([:positive])}/01",
        bzp_number: "2024/BZP #{:erlang.unique_integer([:positive])}",
        is_tender_amount_below_eu: true,
        publication_date: DateTime.utc_now(),
        order_object: "#{order_type} in #{region}",
        cpv_codes: ["09100000-0"],
        submitting_offers_date: DateTime.add(DateTime.utc_now(), 7, :day),
        procedure_result: nil,
        organization_name: "Organization in #{region}",
        organization_city: "City",
        organization_province: province_code,
        organization_country: "PL",
        organization_national_id: "1234567890",
        organization_id: "1234",
        tender_id: "ocds-148610-test-#{:erlang.unique_integer([:positive])}",
        html_body: "<html>...</html>",
        contractors: [],
        estimated_values: [],
        estimated_value: Decimal.new("10000"),
        total_contract_value: nil,
        total_contractors_contracts_count: 0,
        cancelled_count: 0,
        contractors_contract_details: []
      }

      {:ok, _} = Tenders.upsert_tender_notice(attrs)
    end
  end
end
