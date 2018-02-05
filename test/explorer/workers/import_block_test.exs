defmodule Explorer.Workers.ImportBlockTest do
  use Explorer.DataCase
  alias Explorer.Block
  alias Explorer.Repo

  test "perform/1 imports the requested block number as an integer" do
    use_cassette "import_block_perform_1_integer" do
      Explorer.Workers.ImportBlock.perform(1)
      last_block = Block |> order_by(asc: :number) |> Repo.one
      assert last_block.number == 1
    end
  end

  test "perform/1 imports the requested block number as a string" do
    use_cassette "import_block_perform_1_string" do
      Explorer.Workers.ImportBlock.perform("1")
      last_block = Block |> order_by(asc: :number) |> Repo.one
      assert last_block.number == 1
    end
  end

  test "perform/1 imports the earliest block" do
    use_cassette "import_block_perform_1_earliest" do
      Explorer.Workers.ImportBlock.perform("earliest")
      last_block = Block |> order_by(asc: :number) |> Repo.one
      assert last_block.number == 0
    end
  end

  test "perform/1 when there is alaready a block with the requested hash" do
    use_cassette "import_block_perform_1_duplicate" do
      insert(:block, hash: "0x52c867bc0a91e573dc39300143c3bead7408d09d45bdb686749f02684ece72f3")
      Explorer.Workers.ImportBlock.perform("1")
      block_count = Block |> Repo.all |> Enum.count
      assert block_count == 1
    end
  end
end
