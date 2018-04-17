defmodule Explorer.Workers.ImportSkippedBlocksTest do
  use Explorer.DataCase

  import Mock

  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Explorer.Workers.{ImportBlock, ImportSkippedBlocks}

  describe "perform/1" do
    test "imports the requested number of skipped blocks" do
      insert(:block, %{number: 2})

      use_cassette "import_skipped_blocks_perform_1" do
        with_mock ImportBlock, perform_later: fn number -> insert(:block, number: number) end do
          ImportSkippedBlocks.perform(1)
          last_block = Block |> order_by(asc: :number) |> limit(1) |> Repo.one()
          assert last_block.number == 1
        end
      end
    end
  end
end
