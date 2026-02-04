defmodule PrzetargowyPrzeglad.Reports.GraphGenerator do
  @moduledoc """
  Generates SVG graphs for tender reports.

  Creates simple but effective bar charts and line charts using SVG.
  All graphs are generated server-side and stored as strings in the database.
  """

  @doc """
  Generates all graphs for a report.

  ## Parameters

    * `report_data` - Map containing statistics and trends data

  ## Returns

  A map containing SVG strings for each graph type.
  """
  def generate_graphs(report_data) do
    %{
      "tender_count_trend" =>
        generate_weekly_trend_chart(report_data["trends"]["weekly_counts"]),
      "value_distribution" =>
        generate_value_distribution_chart(report_data["statistics"]["by_value_range"])
    }
  end

  @doc """
  Generates a weekly trend bar chart showing tender counts per week.
  """
  def generate_weekly_trend_chart(weekly_data) when is_list(weekly_data) and length(weekly_data) > 0 do
    max_count = weekly_data |> Enum.map(& &1["count"]) |> Enum.max(fn -> 1 end)
    bar_width = 40
    gap = 10
    chart_height = 200

    bars =
      weekly_data
      |> Enum.with_index()
      |> Enum.map(fn {data, index} ->
        count = data["count"]
        height = if max_count > 0, do: (count / max_count * chart_height) |> trunc(), else: 0
        x = index * (bar_width + gap)
        y = chart_height - height

        """
        <rect x="#{x}" y="#{y}" width="#{bar_width}" height="#{height}"
              fill="#3b82f6" rx="2"/>
        <text x="#{x + bar_width / 2}" y="#{chart_height + 15}"
              text-anchor="middle" font-size="12" fill="#6b7280">Tydz. #{data["week"]}</text>
        <text x="#{x + bar_width / 2}" y="#{y - 5}"
              text-anchor="middle" font-size="11" fill="#1f2937" font-weight="600">#{count}</text>
        """
      end)
      |> Enum.join("\n")

    width = length(weekly_data) * (bar_width + gap)

    """
    <svg width="#{width}" height="#{chart_height + 30}" xmlns="http://www.w3.org/2000/svg">
      <title>Liczba przetargów w poszczególnych tygodniach</title>
      #{bars}
    </svg>
    """
  end

  def generate_weekly_trend_chart(_), do: generate_no_data_message("Brak danych tygodniowych")

  @doc """
  Generates a horizontal bar chart showing value distribution.
  """
  def generate_value_distribution_chart(value_ranges)
      when is_list(value_ranges) and length(value_ranges) > 0 do
    max_count = value_ranges |> Enum.map(& &1["count"]) |> Enum.max(fn -> 1 end)
    bar_height = 30
    gap = 10
    chart_width = 400
    label_width = 150

    bars =
      value_ranges
      |> Enum.with_index()
      |> Enum.map(fn {data, index} ->
        count = data["count"]
        width = if max_count > 0, do: (count / max_count * chart_width) |> trunc(), else: 0
        y = index * (bar_height + gap)

        """
        <text x="0" y="#{y + bar_height / 2 + 5}" font-size="14" fill="#1f2937">#{data["label"]}</text>
        <rect x="#{label_width}" y="#{y}" width="#{width}" height="#{bar_height}"
              fill="#10b981" rx="2"/>
        <text x="#{label_width + width + 5}" y="#{y + bar_height / 2 + 5}"
              font-size="12" fill="#1f2937" font-weight="600">#{count}</text>
        """
      end)
      |> Enum.join("\n")

    height = length(value_ranges) * (bar_height + gap)

    """
    <svg width="#{chart_width + label_width + 50}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <title>Rozkład przetargów według wartości</title>
      #{bars}
    </svg>
    """
  end

  def generate_value_distribution_chart(_),
    do: generate_no_data_message("Brak danych o wartościach")

  # Helper function for empty data states
  defp generate_no_data_message(message) do
    """
    <svg width="400" height="100" xmlns="http://www.w3.org/2000/svg">
      <text x="200" y="50" text-anchor="middle" font-size="14" fill="#6b7280">#{message}</text>
    </svg>
    """
  end
end
