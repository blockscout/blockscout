# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.Optimism.DepositsCountTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.Counters.Optimism.DepositsCount

  if Application.compile_env(:explorer, :chain_type) == :optimism do
    test "populates the cache with the number of deposits" do
      insert_list(3, :op_deposit)

      start_supervised!(DepositsCount)
      DepositsCount.consolidate()

      assert DepositsCount.fetch([]) == Decimal.new("3")
    end

    test "does not count deposits with unsuccessful L2 transactions" do
      insert_list(3, :op_deposit)

      failed_transaction = :transaction |> insert() |> with_block(status: :error)
      insert(:op_deposit, l2_transaction: failed_transaction, l2_transaction_hash: failed_transaction.hash)

      start_supervised!(DepositsCount)
      DepositsCount.consolidate()

      assert DepositsCount.fetch([]) == Decimal.new("3")
    end
  end
end
