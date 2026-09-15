# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.CreationDataResolverTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.Chain.{Data, PendingBlockOperation, PendingTransactionOperation}
  alias Explorer.SmartContract.CreationDataResolver
  alias Explorer.Utility.MissingBlockRange

  @internal_transaction_fetcher_supervisor Indexer.Fetcher.InternalTransaction.Supervisor

  @factory "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
  @init "0x6060604052341561000f57600080fd5b336000806101000a8154"
  @code "0x606060405260043610610062576000357c01"

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    resolver_config = Application.get_env(:explorer, CreationDataResolver) || []
    supervisor_config = Application.get_env(:indexer, @internal_transaction_fetcher_supervisor)
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)

    Application.put_env(
      :explorer,
      CreationDataResolver,
      Keyword.merge(resolver_config, enabled: true, max_wait: 100, poll_interval: 10)
    )

    Application.put_env(:indexer, @internal_transaction_fetcher_supervisor, disabled?: false)

    # trace by block (`trace_replayBlockTransactions`) by default; the Geth test overrides this
    Application.put_env(:explorer, :json_rpc_named_arguments,
      transport: EthereumJSONRPC.Mox,
      transport_options: [],
      variant: EthereumJSONRPC.Nethermind
    )

    on_exit(fn ->
      Application.put_env(:explorer, CreationDataResolver, resolver_config)
      restore_env(:indexer, @internal_transaction_fetcher_supervisor, supervisor_config)
      restore_env(:explorer, :json_rpc_named_arguments, json_rpc_named_arguments)
      restore_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, geth_config)
    end)

    address = insert(:contract_address)

    %{address: address, address_hash_string: to_string(address.hash)}
  end

  describe "resolve/1" do
    test "returns {:error, :disabled} without touching the node when disabled", %{address: address} do
      Application.put_env(
        :explorer,
        CreationDataResolver,
        Keyword.merge(Application.get_env(:explorer, CreationDataResolver), enabled: false)
      )

      assert {:error, :disabled} = CreationDataResolver.resolve(address.hash)
    end

    test "returns {:error, :genesis} when the code is present in block 0", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      EthereumJSONRPC.Mox
      |> expect_get_code(address_hash_string, "0x0", @code)

      assert {:error, :genesis} = CreationDataResolver.resolve(address.hash)
    end

    test "rejects a search result that fails the code sanity check", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      insert_blocks(0..4)

      # nonce is 0 everywhere, so the search converges on the right bound (4)
      EthereumJSONRPC.Mox
      |> expect_get_code(address_hash_string, "0x0", "0x")
      |> expect_latest_block("0x4")
      |> expect_nonce(address_hash_string, "0x2", "0x0")
      |> expect_nonce(address_hash_string, "0x3", "0x0")
      |> expect_nonce(address_hash_string, "0x3", "0x0")
      |> expect_get_codes(address_hash_string, %{"0x3" => @code, "0x4" => @code})

      assert {:error, :creation_block_not_found} = CreationDataResolver.resolve(address.hash)
    end

    test "marks the creation block as missing and gives up when it is not imported in time", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      insert_blocks([0, 1, 2, 4])

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)

      assert {:error, :block_not_indexed} = CreationDataResolver.resolve(address.hash)

      assert [%{from_number: 3, to_number: 3, priority: 1}] = Repo.all(MissingBlockRange)
    end

    test "falls back to the default poll interval when the configured one is not positive", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      # a zero interval would otherwise spin without ever consuming max_wait
      Application.put_env(
        :explorer,
        CreationDataResolver,
        Keyword.merge(Application.get_env(:explorer, CreationDataResolver), poll_interval: 0)
      )

      insert_blocks([0, 1, 2, 4])

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)

      assert {:error, :block_not_indexed} = CreationDataResolver.resolve(address.hash)
    end

    test "returns the top-level creation transaction when the DB catches up during the wait", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      insert_blocks([0, 1, 2, 4])

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)

      importer =
        Task.async(fn ->
          :timer.sleep(30)
          block = insert(:block, number: 3)

          :transaction
          |> insert(created_contract_address_hash: address.hash)
          |> with_block(block, status: :ok)
        end)

      assert {:ok, creation_data} = CreationDataResolver.resolve(address.hash)

      transaction = Task.await(importer)

      assert creation_data == %{
               init: Data.to_string(transaction.input),
               block_number: 3,
               transaction_hash: to_string(transaction.hash),
               transaction_index: transaction.index,
               from_address_hash: to_string(transaction.from_address_hash)
             }

      assert [] = Repo.all(PendingBlockOperation)
    end

    test "returns {:error, :tracing_unavailable} when the internal transactions fetcher is disabled", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      Application.put_env(:indexer, @internal_transaction_fetcher_supervisor, disabled?: true)
      insert_blocks(0..4)

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)

      assert {:error, :tracing_unavailable} = CreationDataResolver.resolve(address.hash)
      assert [] = Repo.all(PendingBlockOperation)
    end

    test "traces the block and picks the successful create for the address", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      [_, _, _, block, _] = insert_blocks(0..4)
      transaction = :transaction |> insert() |> with_block(block, status: :ok)
      transaction_hash_string = to_string(transaction.hash)
      other_address_hash_string = to_string(insert(:contract_address).hash)

      traces = [
        nethermind_call_trace(@factory, other_address_hash_string),
        nethermind_create_trace(@factory, "0x01", other_address_hash_string, "0x02", [0]),
        nethermind_create_trace(@factory, "0x03", address_hash_string, "0x04", [1], error: "Out of gas"),
        nethermind_create_trace(@factory, @init, address_hash_string, @code, [2])
      ]

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)
      |> expect_block_trace("0x3", [{transaction_hash_string, traces}])

      assert {:ok,
              %{
                init: @init,
                block_number: 3,
                transaction_hash: ^transaction_hash_string,
                transaction_index: 0,
                from_address_hash: @factory
              }} = CreationDataResolver.resolve(address.hash)

      assert [%{block_number: 3, priority: 1}] = Repo.all(PendingBlockOperation)
    end

    test "returns {:error, :not_found_in_trace} when the block has no creating trace for the address", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      [_, _, _, block, _] = insert_blocks(0..4)
      transaction = :transaction |> insert() |> with_block(block, status: :ok)
      other_address_hash_string = to_string(insert(:contract_address).hash)

      traces = [nethermind_create_trace(@factory, "0x01", other_address_hash_string, "0x02", [0])]

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)
      |> expect_block_trace("0x3", [{to_string(transaction.hash), traces}])

      assert {:error, :not_found_in_trace} = CreationDataResolver.resolve(address.hash)
      assert [] = Repo.all(PendingBlockOperation)
    end

    test "returns {:error, :not_found_in_trace} when the parent transaction failed", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      [_, _, _, block, _] = insert_blocks(0..4)
      transaction = :transaction |> insert() |> with_block(block, status: :error, error: "Reverted")

      traces = [nethermind_create_trace(@factory, @init, address_hash_string, @code, [0])]

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)
      |> expect_block_trace("0x3", [{to_string(transaction.hash), traces}])

      assert {:error, :not_found_in_trace} = CreationDataResolver.resolve(address.hash)
      assert [] = Repo.all(PendingBlockOperation)
    end

    test "returns {:error, :rpc_error} when tracing fails", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      [_, _, _, block, _] = insert_blocks(0..4)
      :transaction |> insert() |> with_block(block, status: :ok)

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)
      |> expect(:json_rpc, fn [%{method: "trace_replayBlockTransactions"}], _ ->
        {:error, %{code: -32000, message: "trace unavailable"}}
      end)

      assert {:error, :rpc_error} = CreationDataResolver.resolve(address.hash)
    end

    test "traces successful transactions one by one on Geth without trace by block", %{
      address: address,
      address_hash_string: address_hash_string
    } do
      Application.put_env(:explorer, :json_rpc_named_arguments,
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        variant: EthereumJSONRPC.Geth
      )

      Application.put_env(
        :ethereum_jsonrpc,
        EthereumJSONRPC.Geth,
        Keyword.merge(Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth) || [],
          tracer: "js",
          block_traceable?: false,
          debug_trace_timeout: "5s"
        )
      )

      [_, _, _, block, _] = insert_blocks(0..4)
      # a failed transaction must not be traced
      :transaction |> insert() |> with_block(block, status: :error, error: "Reverted")
      transaction = :transaction |> insert() |> with_block(block, status: :ok)
      transaction_hash_string = to_string(transaction.hash)

      EthereumJSONRPC.Mox
      |> expect_discovery_of_block_3(address_hash_string)
      |> expect(:json_rpc, fn [%{id: id, method: "debug_traceTransaction", params: [^transaction_hash_string, _]}], _ ->
        {:ok,
         [
           %{
             id: id,
             result: [
               %{
                 "type" => "create",
                 "from" => @factory,
                 "init" => @init,
                 "createdContractAddressHash" => address_hash_string,
                 "createdContractCode" => @code,
                 "traceAddress" => [0],
                 "value" => "0x0",
                 "gas" => "0x106f5",
                 "gasUsed" => "0x106f5"
               }
             ]
           }
         ]}
      end)

      assert {:ok,
              %{
                init: @init,
                block_number: 3,
                transaction_hash: ^transaction_hash_string,
                transaction_index: transaction_index,
                from_address_hash: @factory
              }} = CreationDataResolver.resolve(address.hash)

      assert transaction_index == transaction.index

      pending_hashes =
        PendingTransactionOperation |> Repo.all() |> Enum.map(&{to_string(&1.transaction_hash), &1.priority})

      assert {transaction_hash_string, 1} in pending_hashes
    end
  end

  defp insert_blocks(numbers) do
    now = Timex.now()

    Enum.map(numbers, fn number ->
      insert(:block, number: number, timestamp: Timex.shift(now, minutes: number - 10))
    end)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)

  # genesis check -> latest block -> nonce search (0x2: 0, 0x3: 1) -> sanity check of blocks 2 and 3
  defp expect_discovery_of_block_3(mox, address_hash_string) do
    mox
    |> expect_get_code(address_hash_string, "0x0", "0x")
    |> expect_latest_block("0x4")
    |> expect_nonce(address_hash_string, "0x2", "0x0")
    |> expect_nonce(address_hash_string, "0x3", "0x1")
    |> expect_get_codes(address_hash_string, %{"0x2" => "0x", "0x3" => @code})
  end

  defp expect_get_code(mox, address_hash_string, block_quantity, code) do
    expect(mox, :json_rpc, fn [%{id: id, method: "eth_getCode", params: [^address_hash_string, ^block_quantity]}], _ ->
      {:ok, [%{id: id, result: code}]}
    end)
  end

  defp expect_get_codes(mox, address_hash_string, code_by_block_quantity) do
    expect(mox, :json_rpc, fn requests, _ when is_list(requests) ->
      {:ok,
       Enum.map(requests, fn %{id: id, method: "eth_getCode", params: [^address_hash_string, block_quantity]} ->
         %{id: id, result: Map.fetch!(code_by_block_quantity, block_quantity)}
       end)}
    end)
  end

  defp expect_nonce(mox, address_hash_string, block_quantity, nonce) do
    expect(mox, :json_rpc, fn %{
                                method: "eth_getTransactionCount",
                                params: [^address_hash_string, ^block_quantity]
                              },
                              _ ->
      {:ok, nonce}
    end)
  end

  defp expect_latest_block(mox, number_quantity) do
    expect(mox, :json_rpc, fn [%{id: id, method: "eth_getBlockByNumber", params: ["latest", false]}], _ ->
      {:ok,
       [
         %{
           id: id,
           result: %{
             "difficulty" => "0x0",
             "gasLimit" => "0x0",
             "gasUsed" => "0x0",
             "hash" => "0x29c850324e357f3c0c836d79860c5af55f7b651e5d7ee253c1af1b14908af49c",
             "extraData" => "0x0",
             "logsBloom" => "0x0",
             "miner" => "0x0",
             "number" => number_quantity,
             "parentHash" => "0x0",
             "receiptsRoot" => "0x0",
             "size" => "0x0",
             "sha3Uncles" => "0x0",
             "stateRoot" => "0x0",
             "timestamp" => "0x0",
             "totalDifficulty" => "0x0",
             "transactions" => [],
             "transactionsRoot" => "0x0",
             "uncles" => []
           }
         }
       ]}
    end)
  end

  defp expect_block_trace(mox, block_quantity, traces_by_transaction) do
    expect(mox, :json_rpc, fn [
                                %{id: id, method: "trace_replayBlockTransactions", params: [^block_quantity, ["trace"]]}
                              ],
                              _ ->
      {:ok,
       [
         %{
           id: id,
           result:
             Enum.map(traces_by_transaction, fn {transaction_hash_string, traces} ->
               %{
                 "output" => "0x",
                 "stateDiff" => nil,
                 "trace" => traces,
                 "transactionHash" => transaction_hash_string,
                 "vmTrace" => nil
               }
             end)
         }
       ]}
    end)
  end

  defp nethermind_call_trace(from, to) do
    %{
      "action" => %{
        "callType" => "call",
        "from" => from,
        "gas" => "0x8600",
        "input" => "0x",
        "to" => to,
        "value" => "0x0"
      },
      "result" => %{"gasUsed" => "0x7d37", "output" => "0x"},
      "subtraces" => 3,
      "traceAddress" => [],
      "type" => "call"
    }
  end

  defp nethermind_create_trace(from, init, created_address, code, trace_address, opts \\ []) do
    trace = %{
      "action" => %{"from" => from, "gas" => "0x4d0f0", "init" => init, "value" => "0x0"},
      "result" => %{"address" => created_address, "code" => code, "gasUsed" => "0x28b6b"},
      "subtraces" => 0,
      "traceAddress" => trace_address,
      "type" => "create"
    }

    case Keyword.get(opts, :error) do
      nil -> trace
      error -> Map.put(trace, "error", error)
    end
  end
end
