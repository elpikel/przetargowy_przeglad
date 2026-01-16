defmodule PrzetargowyPrzeglad.Api.BzpClientIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 60_000

  alias PrzetargowyPrzeglad.Api.BzpClient

  # Run with: mix test --only integration

  @tag :integration
  test "fetches real data from BZP API" do
    result = BzpClient.fetch_tenders(page: 0, page_size: 10)

    assert {:ok, %{tenders: tenders, total: total}} = result
    assert is_list(tenders)
    assert total > 0

    if length(tenders) > 0 do
      tender = hd(tenders)
      assert tender.external_id != nil
      assert tender.title != nil
      assert tender.source == "bzp"
    end
  end
end
