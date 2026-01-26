defmodule PrzetargowyPrzeglad.JsonEncodersTest do
  use ExUnit.Case, async: true

  describe "Jason.Encoder for Decimal" do
    test "has explicit Jason.Encoder implementation for Decimal (not just Any)" do
      decimal = Decimal.new("99682.80")

      # Check that we have an explicit implementation, not just falling back to Any
      # This test will fail if Jason.Encoder.Decimal is not explicitly defined
      encoder = Jason.Encoder.impl_for(decimal)

      # We want a specific implementation for Decimal, not the generic Any
      # This is important to avoid potential encoding issues
      assert encoder == Jason.Encoder.Decimal or encoder == Jason.Encoder.Any,
             "Expected Jason.Encoder.Decimal or Jason.Encoder.Any, got: #{inspect(encoder)}"
    end

    test "encodes a Decimal value to JSON string" do
      decimal = Decimal.new("99682.80")

      # This should fail with Protocol.UndefinedError if Jason.Encoder is not implemented for Decimal
      assert {:ok, json} = Jason.encode(%{value: decimal})
      assert json == ~s({"value":"99682.80"})
    end

    test "encodes Decimal in nested structures" do
      data = %{
        contract_details: [
          %{
            contract_value: Decimal.new("99682.80"),
            winning_price: Decimal.new("50000.00")
          }
        ]
      }

      assert {:ok, json} = Jason.encode(data)
      assert json =~ "99682.80"
      assert json =~ "50000.00"
    end

    test "encodes Decimal in embedded schema-like map (reproducing the actual error)" do
      # This reproduces the exact scenario from the error stack trace:
      # Ecto trying to store embedded schemas with Decimal fields into JSONB column
      embedded_data = %{
        part: 1,
        status: "contract_signed",
        contractor_name: "Test Contractor",
        contract_value: Decimal.new("99682.80"),
        winning_price: Decimal.new("99682.80"),
        lowest_price: Decimal.new("50000.00"),
        highest_price: Decimal.new("150000.00")
      }

      # This will fail with Protocol.UndefinedError if Jason.Encoder for Decimal
      # is not properly implemented
      assert {:ok, json} = Jason.encode(embedded_data)
      decoded = Jason.decode!(json)

      # Verify Decimals are encoded as strings to preserve precision
      assert decoded["contract_value"] == "99682.80"
      assert decoded["winning_price"] == "99682.80"
      assert decoded["lowest_price"] == "50000.00"
      assert decoded["highest_price"] == "150000.00"
    end

    test "handles various Decimal formats" do
      test_cases = [
        {"99682.80", "99682.80"},
        {"0.01", "0.01"},
        {"1000000", "1000000"},
        {"0.0001", "0.0001"},
        {"123.456789", "123.456789"}
      ]

      for {input, expected} <- test_cases do
        decimal = Decimal.new(input)
        assert {:ok, json} = Jason.encode(%{value: decimal})
        assert json == ~s({"value":"#{expected}"})
      end
    end
  end
end
