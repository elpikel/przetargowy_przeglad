defmodule PrzetargowyPrzeglad.JsonEncoders do
  @moduledoc """
  Custom JSON encoders for types that don't have default Jason.Encoder implementations.

  This module implements Jason.Encoder for Decimal to ensure proper JSON encoding
  when storing Decimal values in JSONB columns or embedded schemas.

  ## Why this is needed

  Jason 1.4+ includes conditional Decimal support that's only compiled if Decimal
  is available at Jason's compile time. If Jason was compiled in a dependency before
  Decimal was added to your project, the Decimal encoder may not be available, causing
  Protocol.UndefinedError when trying to encode Decimal values.

  This module ensures the Decimal encoder is always available regardless of compilation order.

  ## Note

  You may see a "redefining module" warning if Jason already has Decimal support compiled.
  This is harmless - our implementation will override it to ensure consistent behavior.
  """

  defimpl Jason.Encoder, for: Decimal do
    @moduledoc """
    Encodes a Decimal to a JSON string to preserve precision.

    Decimals are encoded as strings rather than floats to prevent precision loss.
    This is critical for financial calculations where exact decimal precision must
    be maintained.

    ## Examples

        iex> Jason.encode(Decimal.new("99682.80"))
        {:ok, "\\"99682.80\\""}

        iex> Jason.encode(%{price: Decimal.new("123.45")})
        {:ok, "{\\"price\\":\\"123.45\\"}"}
    """
    def encode(decimal, _opts) do
      # Encode as a JSON string (quoted) to preserve precision
      # Using iolist for efficiency, same as Jason's built-in implementation
      [?", Decimal.to_string(decimal), ?"]
    end
  end
end
