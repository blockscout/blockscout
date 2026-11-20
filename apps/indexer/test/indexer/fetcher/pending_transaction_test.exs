# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.PendingTransactionTest do
  # `async: false` due to use of named GenServer
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{EIP8430Transaction, Transaction}
  alias Indexer.Fetcher.{PendingTransaction, ReplacedTransaction}

  # MUST use global mode because we aren't guaranteed to get PendingTransactionFetcher's pid back fast enough to `allow`
  # it to use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  @moduletag [capture_log: true, no_geth: true]

  @eip_8430_transaction_hash "0x3e9e6f89469aca60687eaab43e0a2436e5c23acbe3ccd9dd0342fa6004d99b1c"

  # An EIP-8430 transaction (EIP-2718 type `0x79`) of an OP Stack test network in the form of
  # a pending transaction: without a block. The `calls` list and the block timestamps of the
  # node response are removed.
  @pending_eip_8430_transaction %{
    "accountChanges" => [],
    "blockHash" => nil,
    "blockNumber" => nil,
    "chainId" => "0x509f455",
    "from" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
    "gas" => "0x1255c",
    "gasPrice" => "0x7744d640",
    "hash" => @eip_8430_transaction_hash,
    "input" => "0x",
    "maxFeePerGas" => "0x77541880",
    "maxPriorityFeePerGas" => "0x3baa0c40",
    "metadata" => "0x53706f6e736f726564207472616e73616374696f6e",
    "nonce" => "0x0",
    "nonceKey" => "0x5",
    "payer" => "0xc4bb6341064b99ea7812777be8fd8fa8dfe50c7f",
    "payerAuth" =>
      "0x0000000000000000000000000000000000000001c1a1dc1e515204f16a2d6c18b8f9caacab7c1d49c27b73c1c1786b2f23500a3c0409bd58182d6efbd9a48ebfceadd469dc03f80bd708eca95d539c92082571da1c",
    "sender" => "0x278161ba9f012b85eeb347bf3326988cfbeb3b7a",
    "senderAuth" =>
      "0x0000000000000000000000000000000000000001f4646b5a9fcff6e29768f4d61a65b4479946e37a094a3116f5b76486ce466abf1a514af6b3ed852c8b30fcc82fb76a3e8bb6f9c92c2a77e7055c42bdbb8bdccc1b",
    "to" => nil,
    "transactionIndex" => nil,
    "type" => "0x79",
    "validAfter" => "0x0",
    "validBefore" => "0x1a1c2b2a0b1",
    "value" => "0x0"
  }

  @legacy_transaction_hash "0x4a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"
  @second_legacy_transaction_hash "0x5a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

  # A pending transaction of a different type.
  @pending_legacy_transaction %{
    "blockHash" => nil,
    "blockNumber" => nil,
    "chainId" => "0x509f455",
    "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
    "gas" => "0x5208",
    "gasPrice" => "0x174876e800",
    "hash" => @legacy_transaction_hash,
    "input" => "0x",
    "nonce" => "0x0",
    "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
    "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
    "to" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
    "transactionIndex" => nil,
    "v" => "0xbd",
    "value" => "0x1"
  }

  describe "start_link/1" do
    # this test may fail if Sokol so low volume that the pending transactions are empty for too long
    test "starts fetching pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _json, _options ->
          {:ok,
           [
             %{
               "blockHash" => nil,
               "blockNumber" => nil,
               "chainId" => "0x4d",
               "condition" => nil,
               "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
               "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
               "gas" => "0x47b760",
               "gasPrice" => "0x174876e800",
               "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
               "input" =>
                 "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
               "nonce" => "0x0",
               "publicKey" =>
                 "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
               "r" => "0xad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75",
               "raw" =>
                 "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
               "s" => "0x72caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
               "standardV" => "0x0",
               "to" => nil,
               "transactionIndex" => nil,
               "v" => "0xbd",
               "value" => "0x0"
             }
           ]}
        end)
        |> stub(:json_rpc, fn _json, _options ->
          {:ok, []}
        end)
      end

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      # imported pending transactions are handed to the replaced transaction fetcher
      ReplacedTransaction.Supervisor.Case.start_supervised!()
      PendingTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      pending_hash = "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6"

      wait_for_results(
        fn ->
          Repo.one!(
            from(transaction in Transaction,
              where: is_nil(transaction.block_hash) and transaction.hash == ^pending_hash,
              limit: 1
            )
          )
        end,
        60
      )

      assert Repo.aggregate(Transaction, :count, :hash) >= 1
    end

    test "imports the row of a pending EIP-8430 transaction without the receipt values", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        stub(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options -> {:ok, [@pending_eip_8430_transaction]} end)

        ReplacedTransaction.Supervisor.Case.start_supervised!()
        PendingTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        row =
          wait_for_results(
            fn ->
              Repo.one!(from(row in EIP8430Transaction, where: row.transaction_hash == ^@eip_8430_transaction_hash))
            end,
            60
          )

        assert Decimal.eq?(row.nonce_key, 5)
        assert Decimal.eq?(row.valid_before, 0x1A1C2B2A0B1)
        assert row.payer_type == :named
        assert row.has_named_sender == true
        assert row.resolved_payer_address_hash == nil
        assert row.committed_phases_count == nil

        assert %Transaction{block_hash: nil, type: 0x79} = Repo.get!(Transaction, @eip_8430_transaction_hash)
      end
    end

    test "imports no transaction of a chunk if the row of an EIP-8430 transaction is not valid", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # The first response contains an EIP-8430 transaction without `nonceKey`, so its row is
        # not valid. The fetcher polls in a separate process. Thus each next response contains
        # one valid transaction: when this transaction is in the database, the fetcher is done
        # with the first response.
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn _json, _options ->
          {:ok, [Map.delete(@pending_eip_8430_transaction, "nonceKey"), @pending_legacy_transaction]}
        end)
        |> stub(:json_rpc, fn _json, _options ->
          {:ok, [%{@pending_legacy_transaction | "hash" => @second_legacy_transaction_hash, "nonce" => "0x1"}]}
        end)

        ReplacedTransaction.Supervisor.Case.start_supervised!()
        PendingTransaction.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

        wait_for_results(
          fn -> Repo.one!(from(t in Transaction, where: t.hash == ^@second_legacy_transaction_hash)) end,
          60
        )

        assert Repo.get(Transaction, @eip_8430_transaction_hash) == nil
        assert Repo.get(Transaction, @legacy_transaction_hash) == nil
        assert Repo.aggregate(EIP8430Transaction, :count) == 0
      end
    end
  end
end
