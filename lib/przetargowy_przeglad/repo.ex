defmodule PrzetargowyPrzeglad.Repo do
  use Ecto.Repo,
    otp_app: :przetargowy_przeglad,
    adapter: Ecto.Adapters.Postgres
end
