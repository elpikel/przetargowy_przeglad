defmodule PrzetargowyPrzeglad.Tenders.ContractDetails do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :part, :integer
    field :status, Ecto.Enum, values: [:contract_signed, :cancelled]
    field :contractor_name, :string
    field :contractor_city, :string
    field :contractor_nip, :string
    field :contract_value, :decimal
    field :winning_price, :decimal
    field :lowest_price, :decimal
    field :highest_price, :decimal
    field :cancellation_reason, :string
    field :currency, :string, default: "PLN"
  end

  @doc false
  def changeset(part, attrs) do
    Ecto.Changeset.cast(part, attrs, [
      :part,
      :status,
      :contractor_name,
      :contractor_city,
      :contractor_nip,
      :contract_value,
      :winning_price,
      :lowest_price,
      :highest_price,
      :cancellation_reason,
      :currency
    ])
  end
end
