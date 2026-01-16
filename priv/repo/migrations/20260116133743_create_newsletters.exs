defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateNewsletters do
  use Ecto.Migration

  def change do
    create table(:newsletters) do
      add :issue_number, :integer, null: false
      add :subject, :string, null: false
      add :content_html, :text, null: false
      add :content_text, :text
      add :status, :string, default: "draft"
      add :stats, :map, default: %{}
      add :featured_tender_ids, {:array, :integer}, default: []
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :recipients_count, :integer, default: 0
      add :opens_count, :integer, default: 0
      add :clicks_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:newsletters, [:issue_number])
    create index(:newsletters, [:status])
    create index(:newsletters, [:scheduled_at])
  end
end
