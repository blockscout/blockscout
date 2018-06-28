defmodule Indexer.PendingTransactionFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

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

  describe "start_link/1" do
    @tag :no_geth
    # this test may fail if Sokol so low volume that the pending transactions are empty for too long
    test "starts fetching pending transactions", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      alias Explorer.Chain.Transaction
      alias Indexer.PendingTransactionFetcher

      assert Repo.aggregate(Transaction, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
      start_supervised!({PendingTransactionFetcher, json_rpc_named_arguments: json_rpc_named_arguments})

      wait_for_results(fn ->
        Repo.one!(from(transaction in Transaction, where: is_nil(transaction.block_hash), limit: 1))
      end)

      assert Repo.aggregate(Transaction, :count, :hash) >= 1
    end
  end
end
