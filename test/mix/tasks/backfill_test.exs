defmodule Scrape.Backfill do
  use Explorer.DataCase
  alias Explorer.Block
  alias Explorer.Repo

  test "backfills previous blocks" do
    insert(:block, %{number: 2})

    use_cassette "backfill" do
      Mix.Tasks.Backfill.run([])

      last_block = Block
        |> order_by(asc: :number)
        |> limit(1)
        |> Repo.all
        |> List.first

      assert last_block.number == 1
    end
  end
end
