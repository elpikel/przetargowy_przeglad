defmodule PrzetargowyPrzeglad.JsonEncoders do
  @moduledoc """
  Custom Jason encoders for types that don't have default implementations.
  """

  defimpl Jason.Encoder, for: Decimal do
    @moduledoc """
    Encodes Decimal values as strings to preserve precision.
    This is needed because embedded schemas with Decimal fields are stored as JSON in PostgreSQL.
    """
    def encode(decimal, opts) do
      decimal
      |> Decimal.to_string()
      |> Jason.Encode.string(opts)
    end
  end
end
