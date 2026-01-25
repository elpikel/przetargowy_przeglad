defmodule PrzetargowyPrzeglad.Tenders.Contractor do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :contractor_name, :string
    field :contractor_city, :string
    field :contractor_province, :string
    field :contractor_country, :string
    field :contractor_national_id, :string
  end

  @doc false
  def changeset(contractor, attrs) do
    Ecto.Changeset.cast(contractor, attrs, [
      :contractor_name,
      :contractor_city,
      :contractor_province,
      :contractor_country,
      :contractor_national_id
    ])
  end
end
