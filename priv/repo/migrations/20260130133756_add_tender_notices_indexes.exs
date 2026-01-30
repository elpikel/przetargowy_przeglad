defmodule PrzetargowyPrzeglad.Repo.Migrations.AddTenderNoticesIndexes do
  use Ecto.Migration

  def change do
    # Enable pg_trgm extension for fast ILIKE searches
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm"

    # Index for filtering by notice_type and submitting_offers_date (main search filters)
    create index(:tender_notices, [:notice_type, :submitting_offers_date])

    # Index for filtering by region
    create index(:tender_notices, [:organization_province])

    # Index for filtering by order type
    create index(:tender_notices, [:order_type])

    # GIN trigram indexes for fast ILIKE text search
    execute(
      "CREATE INDEX tender_notices_order_object_trgm_idx ON tender_notices USING GIN (order_object gin_trgm_ops)",
      "DROP INDEX IF EXISTS tender_notices_order_object_trgm_idx"
    )

    execute(
      "CREATE INDEX tender_notices_organization_name_trgm_idx ON tender_notices USING GIN (organization_name gin_trgm_ops)",
      "DROP INDEX IF EXISTS tender_notices_organization_name_trgm_idx"
    )
  end
end
