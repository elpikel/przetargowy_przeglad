defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateTenderReports do
  use Ecto.Migration

  def change do
    create table(:tender_reports) do
      add :title, :string, null: false
      add :slug, :string, null: false

      # Filtering dimensions (null = summary/overall report)
      add :region, :string
      add :order_type, :string

      # Report period
      add :report_month, :date, null: false
      add :cover_image_url, :string

      # Report type flag
      add :report_type, :string, null: false

      # Structured data
      add :report_data, :map, null: false

      # Pre-generated HTML sections
      add :introduction_html, :text
      add :analysis_html, :text
      add :upsell_html, :text

      # SVG graphs stored as strings
      add :graphs, :map

      # SEO
      add :meta_description, :text

      timestamps()
    end

    # Unique constraint for detailed reports
    create unique_index(:tender_reports, [:region, :order_type, :report_month],
             where: "report_type = 'detailed'",
             name: :tender_reports_detailed_unique_idx
           )

    # Unique constraint for summary reports
    create unique_index(:tender_reports, [:report_type, :region, :order_type, :report_month],
             where: "report_type != 'detailed'",
             name: :tender_reports_summary_unique_idx
           )

    # Query indexes
    create index(:tender_reports, [:report_month])
    create unique_index(:tender_reports, [:slug])
  end
end
