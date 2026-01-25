defmodule PrzetargowyPrzeglad.Repo.Migrations.DropTendersTable do
  use Ecto.Migration

  def up do
    drop table(:tenders)
  end

  def down do
    raise "Cannot revert drop_tenders_table migration"
  end
end
