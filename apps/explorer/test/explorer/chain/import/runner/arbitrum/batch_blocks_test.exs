# SPDX-License-Identifier: LicenseRef-Blockscout
if Application.compile_env(:explorer, :chain_type) == :arbitrum do
  defmodule Explorer.Chain.Import.Runner.Arbitrum.BatchBlocksTest do
    use Explorer.DataCase

    alias Ecto.Multi
    alias Explorer.Chain.Arbitrum.BatchBlock
    alias Explorer.Chain.Import.Runner.Arbitrum.BatchBlocks

    describe "insert/3" do
      test "deduplicates a changes list containing two entries with the same block_number, keeping the first" do
        %{number: batch_number} = insert(:arbitrum_l1_batch)
        %{id: first_confirmation_id} = insert(:arbitrum_lifecycle_transaction)
        %{id: second_confirmation_id} = insert(:arbitrum_lifecycle_transaction)

        block_number = 42

        changes = [
          %{
            batch_number: batch_number,
            block_number: block_number,
            confirmation_id: first_confirmation_id
          },
          %{
            batch_number: batch_number,
            block_number: block_number,
            confirmation_id: second_confirmation_id
          }
        ]

        assert {:ok, %{insert_arbitrum_batch_blocks: inserted}} = run_changes(changes)

        assert length(inserted) == 1

        assert [%BatchBlock{block_number: ^block_number, confirmation_id: ^first_confirmation_id}] =
                 Repo.all(from(bb in BatchBlock, where: bb.block_number == ^block_number))
      end

      test "imports all rows for a well-formed list without duplicates" do
        %{number: batch_number} = insert(:arbitrum_l1_batch)
        %{id: first_confirmation_id} = insert(:arbitrum_lifecycle_transaction)
        %{id: second_confirmation_id} = insert(:arbitrum_lifecycle_transaction)

        changes = [
          %{
            batch_number: batch_number,
            block_number: 1,
            confirmation_id: first_confirmation_id
          },
          %{
            batch_number: batch_number,
            block_number: 2,
            confirmation_id: second_confirmation_id
          }
        ]

        assert {:ok, %{insert_arbitrum_batch_blocks: inserted}} = run_changes(changes)

        assert length(inserted) == 2

        assert Repo.aggregate(from(bb in BatchBlock, where: bb.block_number in [1, 2]), :count) == 2
      end
    end

    defp run_changes(changes) when is_list(changes) do
      Multi.new()
      |> BatchBlocks.run(changes, %{
        timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
      })
      |> Repo.transaction()
    end
  end
end
