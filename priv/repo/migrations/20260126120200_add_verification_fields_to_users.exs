defmodule PrzetargowyPrzeglad.Repo.Migrations.AddVerificationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified, :boolean, default: false, null: false
      add :email_verification_token, :string
      add :email_verification_sent_at, :utc_datetime
    end

    create index(:users, [:email_verification_token])
  end
end
