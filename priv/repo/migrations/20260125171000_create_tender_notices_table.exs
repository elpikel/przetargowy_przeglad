defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateTenderNoticesTable do
  use Ecto.Migration

  def change do
    create table(:tender_notices, primary_key: false) do
      add :object_id, :text, primary_key: true
      add :client_type, :text
      add :order_type, :text
      add :tender_type, :text
      add :notice_type, :text
      add :notice_number, :text
      add :bzp_number, :text
      add :is_tender_amount_below_eu, :boolean
      add :publication_date, :utc_datetime
      add :order_object, :text
      add :cpv_codes, {:array, :text}, default: []
      add :submitting_offers_date, :utc_datetime
      add :procedure_result, :text
      add :organization_name, :text
      add :organization_city, :text
      add :organization_province, :text
      add :organization_country, :text
      add :organization_national_id, :text
      add :organization_id, :text
      add :tender_id, :text
      add :html_body, :text
      add :estimated_values, {:array, :decimal}, default: []
      add :estimated_value, :decimal
      add :total_contract_value, :decimal
      add :total_contractors_contracts_count, :integer
      add :cancelled_count, :integer
      add :contractors, :map
      add :contractors_contract_details, :map

      timestamps()
    end
  end
end
