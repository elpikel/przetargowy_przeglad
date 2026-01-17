defmodule PrzetargowyPrzeglad.Newsletters do
  import Ecto.Query
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Newsletter.{Newsletter, Generator}

  def generate_weekly do
    Generator.generate()
  end

  def get_newsletter(id), do: Repo.get(Newsletter, id)

  def get_by_issue(issue_number) do
    Repo.get_by(Newsletter, issue_number: issue_number)
  end

  def get_latest do
    Newsletter
    |> order_by([n], desc: n.issue_number)
    |> limit(1)
    |> Repo.one()
  end

  def get_ready_to_send do
    Newsletter
    |> where([n], n.status == "generated")
    |> order_by([n], desc: n.issue_number)
    |> limit(1)
    |> Repo.one()
  end

  def list_newsletters(opts \\ []) do
    Newsletter
    |> maybe_filter_status(opts[:status])
    |> order_by([n], desc: n.issue_number)
    |> limit(^(opts[:limit] || 20))
    |> Repo.all()
  end

  def update_status(newsletter, status) do
    newsletter
    |> Newsletter.changeset(%{status: status})
    |> Repo.update()
  end

  def mark_sent(newsletter, recipients_count) do
    newsletter
    |> Newsletter.mark_sent(recipients_count)
    |> Repo.update()
  end

  def count_all do
    Repo.aggregate(Newsletter, :count)
  end

  def count_by_status(status) do
    Newsletter
    |> where([n], n.status == ^status)
    |> Repo.aggregate(:count)
  end

  def get_last_sent do
    Newsletter
    |> where([n], n.status == "sent")
    |> order_by([n], desc: n.sent_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_next_scheduled do
    Newsletter
    |> where([n], n.status == "generated")
    |> where([n], not is_nil(n.scheduled_at))
    |> order_by([n], asc: n.scheduled_at)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [n], n.status == ^status)
  end
end
