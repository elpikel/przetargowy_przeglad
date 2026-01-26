defmodule PrzetargowyPrzeglad.JsonEncoders do
  @moduledoc """
  Custom Jason encoders for types that don't have default implementations.

  This module implements Jason.Encoder for Decimal to encode values as strings,
  preserving precision. This is necessary because embedded schemas with Decimal
  fields are stored as JSONB in PostgreSQL.

  Note: The compiler warning about redefining Jason.Encoder.Decimal is expected
  and harmless. Jason includes a stub module that we intentionally override with
  our string-based encoding implementation.
  """

  defimpl Jason.Encoder, for: Decimal do
    @moduledoc """
    Encodes Decimal values as JSON strings to preserve precision.

    Example:
        iex> Jason.encode(%{value: Decimal.new("896411.70")})
        {:ok, ~s({"value":"896411.70"})}
    """
    def encode(decimal, opts) do
      decimal
      |> Decimal.to_string()
      |> Jason.Encode.string(opts)
    end
  end
end
