defmodule Explorer.LatestBlockTest do
  use Explorer.DataCase

  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.LatestBlock

  describe "fetch/0" do
    test "the latest block is copied over from the blockchain" do
      use_cassette "latest_block_fetch" do
        LatestBlock.fetch()

        last_block = Block
          |> order_by(desc: :inserted_at)
          |> limit(1)
          |> Repo.all
          |> List.first

        assert(last_block.number)
      end
    end
  end

  describe "get_latest_block/0" do
    test "returns the number of the latest block" do
      use_cassette "fetcher_get_latest_block" do
        assert LatestBlock.get_latest_block() == "0x89923"
      end
    end
  end
end
