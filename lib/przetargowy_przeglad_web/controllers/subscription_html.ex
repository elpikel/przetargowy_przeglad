defmodule PrzetargowyPrzegladWeb.SubscriptionHTML do
  @moduledoc """
  HTML templates for subscription management pages.
  """
  use PrzetargowyPrzegladWeb, :html

  embed_templates "subscription_html/*"

  @doc """
  Formats a subscription status for display.
  """
  def format_status("active"), do: "Aktywna"
  def format_status("pending"), do: "Oczekująca"
  def format_status("cancelled"), do: "Anulowana"
  def format_status("expired"), do: "Wygasła"
  def format_status("failed"), do: "Niepowodzenie płatności"
  def format_status(_), do: "Nieznany"

  @doc """
  Returns CSS class for status badge.
  """
  def status_class("active"), do: "bg-green-100 text-green-800"
  def status_class("pending"), do: "bg-yellow-100 text-yellow-800"
  def status_class("cancelled"), do: "bg-gray-100 text-gray-800"
  def status_class("expired"), do: "bg-red-100 text-red-800"
  def status_class("failed"), do: "bg-red-100 text-red-800"
  def status_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Formats a transaction type for display.
  """
  def format_transaction_type("initial"), do: "Pierwsza płatność"
  def format_transaction_type("renewal"), do: "Odnowienie"
  def format_transaction_type("refund"), do: "Zwrot"
  def format_transaction_type(_), do: "Płatność"

  @doc """
  Formats a transaction status for display.
  """
  def format_transaction_status("completed"), do: "Zakończona"
  def format_transaction_status("pending"), do: "W trakcie"
  def format_transaction_status("failed"), do: "Niepowodzenie"
  def format_transaction_status("refunded"), do: "Zwrócona"
  def format_transaction_status(_), do: "Nieznany"

  @doc """
  Returns CSS class for transaction status.
  """
  def transaction_status_class("completed"), do: "text-green-600"
  def transaction_status_class("pending"), do: "text-yellow-600"
  def transaction_status_class("failed"), do: "text-red-600"
  def transaction_status_class("refunded"), do: "text-blue-600"
  def transaction_status_class(_), do: "text-gray-600"

  @doc """
  Formats a date for display.
  """
  def format_date(nil), do: "-"

  def format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y")
  end

  @doc """
  Formats a datetime for display.
  """
  def format_datetime(nil), do: "-"

  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%d.%m.%Y %H:%M")
  end

  @doc """
  Formats an amount for display.
  """
  def format_amount(nil), do: "-"

  def format_amount(%Decimal{} = amount) do
    "#{Decimal.round(amount, 2)} PLN"
  end

  def format_amount(amount) when is_number(amount) do
    "#{:erlang.float_to_binary(amount / 1, decimals: 2)} PLN"
  end
end
