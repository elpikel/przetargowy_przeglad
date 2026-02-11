defmodule PrzetargowyPrzeglad.Repo.Migrations.AddEvaluationCriteriaToTenderNotices do
  use Ecto.Migration

  def change do
    alter table(:tender_notices) do
      add :evaluation_criteria, :text
    end
  end
end
