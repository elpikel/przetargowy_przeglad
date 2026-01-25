defmodule PrzetargowyPrzeglad.Tenders.TenderNotice do
  @moduledoc """
  Schema for public tenders notices.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:object_id, :string, autogenerate: false}
  schema "tender_notices" do
    field :client_type, :string
    field :order_type, :string
    field :tender_type, :string
    field :notice_type, :string
    field :notice_number, :string
    field :bzp_number, :string
    field :is_tender_amount_below_eu, :boolean
    field :publication_date, :utc_datetime
    field :order_object, :string
    field :cpv_codes, {:array, :string}, default: []
    field :submitting_offers_date, :utc_datetime
    field :procedure_result, :string
    field :organization_name, :string
    field :organization_city, :string
    field :organization_province, :string
    field :organization_country, :string
    field :organization_national_id, :string
    field :organization_id, :string
    field :tender_id, :string
    field :html_body, :string
    field :estimated_values, {:array, :float}, default: []
    field :estimated_value, :float
    field :total_contract_value, :float
    field :total_contractors_contracts_count, :integer
    field :cancelled_count, :integer

    embeds_many :contractors, PrzetargowyPrzeglad.Tenders.Contractor
    embeds_many :contractors_contract_details, PrzetargowyPrzeglad.Tenders.ContractDetails

    timestamps()
  end

  @doc false
  def changeset(tender, attrs) do
    tender
    |> cast(attrs, [
      :object_id,
      :client_type,
      :order_type,
      :tender_type,
      :notice_type,
      :notice_number,
      :bzp_number,
      :is_tender_amount_below_eu,
      :publication_date,
      :order_object,
      :cpv_codes,
      :submitting_offers_date,
      :procedure_result,
      :organization_name,
      :organization_city,
      :organization_province,
      :organization_country,
      :organization_national_id,
      :organization_id,
      :tender_id,
      :html_body,
      :estimated_values,
      :estimated_value,
      :total_contract_value,
      :total_contractors_contracts_count,
      :cancelled_count
    ])
    |> cast_embed(:contractors)
    |> cast_embed(:contractors_contract_details)
    |> validate_required([
      :object_id,
      :client_type,
      :order_type,
      :tender_type,
      :notice_type,
      :notice_number,
      :bzp_number,
      :is_tender_amount_below_eu,
      :publication_date,
      :order_object,
      :cpv_codes,
      :procedure_result,
      :organization_name,
      :organization_city,
      :organization_country,
      :organization_national_id,
      :organization_id,
      :tender_id,
      :html_body
    ])
  end
end
