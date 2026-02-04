defmodule PrzetargowyPrzegladWeb.ReportHTML do
  @moduledoc """
  HTML helpers and templates for ReportController.
  """
  use PrzetargowyPrzegladWeb, :html

  embed_templates "report_html/*"

  @doc """
  Formats a report date in Polish.

  ## Examples

      iex> format_report_date(~D[2026-01-01])
      "styczeń 2026"
  """
  def format_report_date(date) do
    months = [
      "styczeń",
      "luty",
      "marzec",
      "kwiecień",
      "maj",
      "czerwiec",
      "lipiec",
      "sierpień",
      "wrzesień",
      "październik",
      "listopad",
      "grudzień"
    ]

    month_name = Enum.at(months, date.month - 1)
    "#{month_name} #{date.year}"
  end

  @doc """
  Formats a region name from code to display name.

  ## Examples

      iex> format_region_name("mazowieckie")
      "Mazowieckie"
  """
  def format_region_name(nil), do: "Polska"

  def format_region_name(region) do
    region_options()
    |> Enum.find(fn {code, _} -> code == region end)
    |> case do
      {_, name} -> name
      nil -> region
    end
  end

  @doc """
  Formats order type to Polish display name.

  ## Examples

      iex> format_order_type("Delivery")
      "Dostawy"
  """
  def format_order_type("Delivery"), do: "Dostawy"
  def format_order_type("Services"), do: "Usługi"
  def format_order_type("Works"), do: "Roboty budowlane"
  def format_order_type(nil), do: "Wszystkie kategorie"
  def format_order_type(type), do: type

  @doc """
  Gets a short summary text from report data.
  """
  def get_summary_text(report_data) do
    total = report_data["summary"]["total_tenders"]
    "Analiza #{total} przetargów publicznych wraz ze statystykami i trendami rynkowymi."
  end

  @doc """
  Formats a currency value with Polish formatting.

  ## Examples

      iex> format_currency("1500000.00")
      "1 500 000 PLN"
  """
  def format_currency(value_string) when is_binary(value_string) do
    value_string
    |> Decimal.new()
    |> format_currency()
  end

  def format_currency(%Decimal{} = decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1 ")
    |> Kernel.<>(" PLN")
  end

  def format_currency(_), do: "—"

  @doc """
  Truncates text to a maximum length.

  ## Examples

      iex> truncate_text("Very long text here", 10)
      "Very long ..."
  """
  def truncate_text(nil, _length), do: ""
  def truncate_text(string, length) when byte_size(string) <= length, do: string

  def truncate_text(string, length) do
    String.slice(string, 0, length) <> "..."
  end

  @doc """
  Builds a URL for pagination.

  ## Examples

      iex> build_url(2)
      "/reports?page=2"

      iex> build_url(1)
      "/reports"
  """
  def build_url(1), do: "/reports"
  def build_url(page), do: "/reports?page=#{page}"

  @doc """
  Returns a list of region options for filters.
  """
  def region_options do
    [
      {"dolnoslaskie", "Dolnośląskie"},
      {"kujawsko-pomorskie", "Kujawsko-pomorskie"},
      {"lubelskie", "Lubelskie"},
      {"lubuskie", "Lubuskie"},
      {"lodzkie", "Łódzkie"},
      {"malopolskie", "Małopolskie"},
      {"mazowieckie", "Mazowieckie"},
      {"opolskie", "Opolskie"},
      {"podkarpackie", "Podkarpackie"},
      {"podlaskie", "Podlaskie"},
      {"pomorskie", "Pomorskie"},
      {"slaskie", "Śląskie"},
      {"swietokrzyskie", "Świętokrzyskie"},
      {"warminsko-mazurskie", "Warmińsko-mazurskie"},
      {"wielkopolskie", "Wielkopolskie"},
      {"zachodniopomorskie", "Zachodniopomorskie"}
    ]
  end

  @doc """
  Returns a list of order type options for filters.
  """
  def order_type_options do
    [
      {"Delivery", "Dostawy"},
      {"Services", "Usługi"},
      {"Works", "Roboty budowlane"}
    ]
  end

  @doc """
  Formats report type to display name.
  """
  def format_report_type("detailed"), do: "Szczegółowy"
  def format_report_type("region_summary"), do: "Podsumowanie regionu"
  def format_report_type("industry_summary"), do: "Podsumowanie branży"
  def format_report_type("overall"), do: "Podsumowanie ogólne"
  def format_report_type(_), do: "Raport"
end
