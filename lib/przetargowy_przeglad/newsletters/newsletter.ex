defmodule PrzetargowyPrzeglad.Newsletter.Newsletter do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft generated sending sent)

  schema "newsletters" do
    field :issue_number, :integer
    field :subject, :string
    field :content_html, :string
    field :content_text, :string
    field :status, :string, default: "draft"
    field :stats, :map, default: %{}
    field :featured_tender_ids, {:array, :integer}, default: []
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :recipients_count, :integer, default: 0
    field :opens_count, :integer, default: 0
    field :clicks_count, :integer, default: 0

    timestamps()
  end

  def changeset(newsletter, attrs) do
    newsletter
    |> cast(attrs, [
      :issue_number,
      :subject,
      :content_html,
      :content_text,
      :status,
      :stats,
      :featured_tender_ids,
      :scheduled_at,
      :sent_at,
      :recipients_count,
      :opens_count,
      :clicks_count
    ])
    |> validate_required([:issue_number, :subject, :content_html])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:issue_number)
  end

  def mark_generated(newsletter) do
    change(newsletter, status: "generated")
  end

  def mark_sending(newsletter) do
    change(newsletter, status: "sending")
  end

  def mark_sent(newsletter, recipients_count) do
    newsletter
    |> change()
    |> put_change(:status, "sent")
    |> put_change(:sent_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> put_change(:recipients_count, recipients_count)
  end

  def statuses, do: @statuses
end
