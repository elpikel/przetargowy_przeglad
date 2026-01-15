defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateTenders do
  use Ecto.Migration

  def change do
    create table(:tenders) do
      # Identyfikatory
      add :external_id, :string, null: false
      add :source, :string, null: false

      # Dane podstawowe
      add :title, :text, null: false
      add :description, :text
      add :notice_type, :string

      # Zamawiający
      add :contracting_authority_name, :string
      add :contracting_authority_city, :string
      add :contracting_authority_region, :string

      # Wartość i terminy
      add :estimated_value, :decimal, precision: 15, scale: 2
      add :currency, :string, default: "PLN"
      add :submission_deadline, :utc_datetime
      add :publication_date, :utc_datetime

      # Kategoryzacja
      add :cpv_codes, {:array, :string}, default: []
      add :industry, :string
      add :procedure_type, :string

      # Wyniki (opcjonalne)
      add :offers_count, :integer
      add :winning_price, :decimal, precision: 15, scale: 2
      add :winner_name, :string

      # Metadane
      add :url, :text
      add :raw_data, :map
      add :fetched_at, :utc_datetime

      timestamps()
    end

    create unique_index(:tenders, [:external_id, :source])
    create index(:tenders, [:industry])
    create index(:tenders, [:contracting_authority_region])
    create index(:tenders, [:submission_deadline])
    create index(:tenders, [:publication_date])
    create index(:tenders, [:estimated_value])
  end
end
