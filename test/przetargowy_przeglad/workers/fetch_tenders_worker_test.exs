defmodule PrzetargowyPrzeglad.Workers.FetchTendersWorkerTest do
  use PrzetargowyPrzeglad.DataCase
  use Oban.Testing, repo: PrzetargowyPrzeglad.Repo

  alias PrzetargowyPrzeglad.Workers.FetchTendersWorker
  alias PrzetargowyPrzeglad.Tenders

  describe "enqueue/1" do
    test "creates job with correct args" do
      assert {:ok, job} = FetchTendersWorker.enqueue(days: 7, max_pages: 10)
      assert job.args["days"] == 7
      assert job.args["max_pages"] == 10
    end
  end

  describe "perform/1" do
    @tag :integration
    test "fetches and stores tenders" do
      # This would need mocking in real tests
      # For now, skip or use integration tag
      :ok
    end
  end
end
