# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Arbitrum.Reader.API.GeneralTest do
  use Explorer.DataCase

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents
  alias Explorer.Chain.{Address, Data, Hash, Log}
  alias Explorer.Chain.Arbitrum.Reader.API.General
  alias Explorer.Utility.LogFirstTopic

  describe "transaction_to_logs_by_topic0/2" do
    test "restores the fields of logs stored in the optimized format" do
      # logs without `first_topic` are found by `first_topic_id` only once the migration is started
      set_fill_logs_optimized_fields_migration_started()

      transaction = :transaction |> insert() |> with_block()
      %Address{hash: address_hash} = address = insert(:address)
      {:ok, first_topic} = Hash.Full.cast(ArbitrumEvents.l2_to_l1())
      data = %Data{bytes: <<1, 2, 3>>}

      # `address_hash`, `first_topic` and `data` are kept only in `address_id`,
      # `first_topic_id` and `compressed_data` since v12
      insert(:log,
        transaction: transaction,
        block: transaction.block,
        block_number: transaction.block_number,
        address: address,
        address_hash: nil,
        first_topic: nil,
        first_topic_id: LogFirstTopic.find_or_create(first_topic).id,
        data: nil,
        compressed_data: data
      )

      assert [%Log{address_hash: ^address_hash, first_topic: ^first_topic, data: ^data}] =
               General.transaction_to_logs_by_topic0(transaction.hash, ArbitrumEvents.l2_to_l1())
    end
  end
end
