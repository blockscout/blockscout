defmodule Scrape.Test do
  use Explorer.DataCase
  alias Explorer.Block
  alias Explorer.Repo

  test "it downloads a new block" do
    Mix.Tasks.Scrape.run([])

    last_block = Block
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.all
      |> List.first

    assert(last_block.number)
  end
end
