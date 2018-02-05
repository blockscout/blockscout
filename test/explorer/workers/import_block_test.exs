defmodule Explorer.Workers.ImportBlockTest do
  alias Explorer.Block
  alias Explorer.Repo
  alias Explorer.Workers.ImportBlock

  import Mock

  use Explorer.DataCase

  describe "perform/1" do
    test "imports the requested block number as an integer" do
      use_cassette "import_block_perform_1_integer" do
        ImportBlock.perform(1)
        last_block = Block |> order_by(asc: :number) |> Repo.one
        assert last_block.number == 1
      end
    end

    test "imports the requested block number as a string" do
      use_cassette "import_block_perform_1_string" do
        ImportBlock.perform("1")
        last_block = Block |> order_by(asc: :number) |> Repo.one
        assert last_block.number == 1
      end
    end

    test "imports the earliest block" do
      use_cassette "import_block_perform_1_earliest" do
        ImportBlock.perform("earliest")
        last_block = Block |> order_by(asc: :number) |> Repo.one
        assert last_block.number == 0
      end
    end

    test "when there is already a block with the requested hash" do
      use_cassette "import_block_perform_1_duplicate" do
        insert(:block, hash: "0x52c867bc0a91e573dc39300143c3bead7408d09d45bdb686749f02684ece72f3")
        ImportBlock.perform("1")
        block_count = Block |> Repo.all |> Enum.count
        assert block_count == 1
      end
    end
  end

  describe "perform_later/1" do
    test "does not retry fetching the latest block" do
      use_cassette "import_block_perform_later_1_latest" do
        with_mock Exq, [enqueue: fn (_, _, _, _, max_retries: 0) -> insert(:block, number: 1) end] do
          ImportBlock.perform_later("latest")
          last_block = Block |> order_by(asc: :number) |> limit(1) |> Repo.one
          assert last_block.number == 1
        end
      end
    end
  end
end
