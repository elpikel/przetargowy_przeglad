defmodule PrzetargowyPrzeglad.Repo.Migrations.AddParsedFieldsToTenderNotices do
  use Ecto.Migration

  def change do
    alter table(:tender_notices) do
      # Wadium (deposit/bid bond)
      add :wadium, :text
      add :wadium_amount, :decimal

      # Evaluation criteria (stored as JSONB array)
      add :kryteria, {:array, :map}, default: []

      # Contract execution period
      add :okres_realizacji_from, :date
      add :okres_realizacji_to, :date
      add :okres_realizacji_raw, :text

      # Tender description and requirements
      add :opis_przedmiotu, :text
      add :warunki_udzialu, :text

      # CPV codes (main already exists as cpv_codes, adding explicit main and additional)
      add :cpv_main, :text
      add :cpv_additional, {:array, :text}, default: []

      # Reference number
      add :numer_referencyjny, :text

      # Tender options
      add :oferty_czesciowe, :boolean
      add :zabezpieczenie, :boolean

      # Extended organization/contracting authority info
      add :organization_email, :text
      add :organization_www, :text
      add :organization_regon, :text
      add :organization_street, :text
      add :organization_postal_code, :text
    end
  end
end
