defmodule PrzetargowyPrzeglad.Email do
  def from_address do
    config = Application.get_env(:przetargowy_przeglad, :mail_from, [])
    {config[:name] || "Newsletter", config[:address] || "newsletter@example.com"}
  end
end
