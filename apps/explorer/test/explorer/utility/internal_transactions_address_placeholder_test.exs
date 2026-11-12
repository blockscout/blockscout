# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.InternalTransactionsAddressPlaceholderTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Utility.InternalTransactionsAddressPlaceholder

  describe "insert_for_internal_transactions/3" do
    test "adds the counts of separate batches of the same block" do
      %{address_id: address_id} = insert(:address_id_to_address_hash, address: insert(:address))
      %{address_id: other_address_id} = insert(:address_id_to_address_hash, address: insert(:address))

      # the internal transactions of different transactions of the block go in opposite directions
      InternalTransactionsAddressPlaceholder.insert_for_internal_transactions(Repo, [
        %{block_number: 1, index: 1, from_address_id: address_id, to_address_id: other_address_id}
      ])

      InternalTransactionsAddressPlaceholder.insert_for_internal_transactions(Repo, [
        %{block_number: 1, index: 1, from_address_id: other_address_id, to_address_id: address_id}
      ])

      assert placeholders() == MapSet.new([{address_id, 1, 1, 1}, {other_address_id, 1, 1, 1}])
    end

    test "caps the counts at the smallint maximum" do
      %{address_id: address_id} = insert(:address_id_to_address_hash, address: insert(:address))

      insert(:deleted_internal_transactions_address_placeholder,
        address_id: address_id,
        block_number: 1,
        count_tos: 32_767,
        count_froms: 32_760
      )

      self_calls =
        for index <- 1..10 do
          %{block_number: 1, index: index, from_address_id: address_id, to_address_id: address_id}
        end

      InternalTransactionsAddressPlaceholder.insert_for_internal_transactions(Repo, self_calls)

      assert placeholders() == MapSet.new([{address_id, 1, 32_767, 32_767}])
    end
  end

  describe "delete_by_block_numbers/3" do
    setup do
      %{address_id: address_id} = insert(:address_id_to_address_hash, address: insert(:address))

      for block_number <- 1..3 do
        insert(:deleted_internal_transactions_address_placeholder, address_id: address_id, block_number: block_number)
      end

      initial_index_finished? =
        BackgroundMigrations.get_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished()

      on_exit(fn -> set_block_number_index_finished(initial_index_finished?) end)

      %{address_id: address_id}
    end

    test "deletes the placeholders of the given blocks", %{address_id: address_id} do
      set_block_number_index_finished(true)

      assert 2 = InternalTransactionsAddressPlaceholder.delete_by_block_numbers(Repo, [1, 3])

      assert placeholders() == MapSet.new([{address_id, 2, 1, 1}])
    end

    test "does nothing until the index on block_number is created", %{address_id: address_id} do
      set_block_number_index_finished(false)

      assert 0 = InternalTransactionsAddressPlaceholder.delete_by_block_numbers(Repo, [1, 3])

      assert placeholders() == MapSet.new(1..3, &{address_id, &1, 1, 1})
    end
  end

  defp set_block_number_index_finished(finished?) do
    BackgroundMigrations.set_heavy_indexes_create_deleted_internal_transactions_address_placeholders_block_number_index_finished(
      finished?
    )
  end

  defp placeholders do
    InternalTransactionsAddressPlaceholder
    |> Repo.all()
    |> MapSet.new(&{&1.address_id, &1.block_number, &1.count_tos, &1.count_froms})
  end
end
