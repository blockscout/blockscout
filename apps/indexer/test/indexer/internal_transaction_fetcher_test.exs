defmodule Indexer.InternalTransactionFetcherTest do
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Indexer.{AddressBalanceFetcherCase, InternalTransactionFetcher}

  @moduletag :capture_log

  setup do
    {variant, url} =
      case System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity" do
        "geth" ->
          {EthereumJSONRPC.Geth, "https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY"}

        "parity" ->
          {EthereumJSONRPC.Parity, "https://sokol-trace.poa.network"}

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end

    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          url: url,
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ],
        variant: variant
      ]
    }
  end

  @tag :no_geth
  test "does not try to fetch pending transactions from Indexer.PendingTransactionFetcher", %{
    json_rpc_named_arguments: json_rpc_named_arguments
  } do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)
    start_supervised!({Indexer.PendingTransactionFetcher, json_rpc_named_arguments: json_rpc_named_arguments})

    wait_for_results(fn ->
      Repo.one!(from(transaction in Explorer.Chain.Transaction, where: is_nil(transaction.block_hash), limit: 1))
    end)

    :transaction
    |> insert(hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6")
    |> with_block()

    hash_strings =
      InternalTransactionFetcher.init([], fn hash_string, acc -> [hash_string | acc] end, json_rpc_named_arguments)

    assert :ok = InternalTransactionFetcher.run(hash_strings, 0, json_rpc_named_arguments)
  end

  describe "init/2" do
    test "does not buffer pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:transaction)

      assert InternalTransactionFetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == []
    end

    test "buffers collated transactions with unfetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)

      collated_unfetched_transaction =
        :transaction
        |> insert()
        |> with_block(block)

      assert InternalTransactionFetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == [
               %{block_number: block.number, hash_data: to_string(collated_unfetched_transaction.hash)}
             ]
    end

    test "does not buffer collated transactions with fetched internal transactions", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      :transaction
      |> insert()
      |> with_block(internal_transactions_indexed_at: DateTime.utc_now())

      assert InternalTransactionFetcher.init(
               [],
               fn hash_string, acc -> [hash_string | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "run/2" do
    test "duplicate transaction hashes are logged", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      insert(:transaction, hash: "0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa")

      log =
        capture_log(fn ->
          InternalTransactionFetcher.run(
            [
              %{block_number: 1, hash_data: "0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa"},
              %{block_number: 1, hash_data: "0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa"}
            ],
            0,
            json_rpc_named_arguments
          )
        end)

      assert log =~
               """
               Duplicate transaction params being used to fetch internal transactions:
                 1. %{block_number: 1, hash_data: \"0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa\"}
                 2. %{block_number: 1, hash_data: \"0x03cd5899a63b6f6222afda8705d059fd5a7d126bcabe962fb654d9736e6bcafa\"}
               """
    end

    @tag :no_geth
    test "duplicate transaction hashes only retry uniques", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      # not a real transaction hash, so that it fails
      insert(:transaction, hash: "0x0000000000000000000000000000000000000000000000000000000000000001")

      assert InternalTransactionFetcher.run(
               [
                 %{block_number: 1, hash_data: "0x0000000000000000000000000000000000000000000000000000000000000001"},
                 %{block_number: 1, hash_data: "0x0000000000000000000000000000000000000000000000000000000000000001"}
               ],
               0,
               json_rpc_named_arguments
             ) ==
               {:retry,
                [%{block_number: 1, hash_data: "0x0000000000000000000000000000000000000000000000000000000000000001"}]}
    end
  end
end
