# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.InternalTransactionsAddressPlaceholderTest do
  use Explorer.DataCase

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

  defp placeholders do
    InternalTransactionsAddressPlaceholder
    |> Repo.all()
    |> MapSet.new(&{&1.address_id, &1.block_number, &1.count_tos, &1.count_froms})
  end
end
