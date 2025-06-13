defmodule Indexer.Fetcher.ZkSync.Utils.RpcTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Hash
  alias Indexer.Fetcher.ZkSync.Utils.Rpc, as: ZksyncRpc

  setup :set_mox_global
  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "fetch_transaction_by_hash/2" do
    test "returns transaction data for a valid transaction hash", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      transaction_hash = "0x3078313131313131313131313131313131313131313131313131313131313131"
      raw_transaction_hash = "3078313131313131313131313131313131313131313131313131313131313131" |> Base.decode16!()

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn
          %{id: _id, method: "eth_getTransactionByHash", params: [^transaction_hash]}, _options ->
            {:ok,
             %{
               "hash" => transaction_hash
             }}

          %{id: _id, method: "eth_getTransactionByHash", params: [%Hash{bytes: ^raw_transaction_hash}]}, _options ->
            {:ok,
             %{
               "hash" => transaction_hash
             }}
        end
      )

      assert %{"hash" => ^transaction_hash} =
               ZksyncRpc.fetch_transaction_by_hash(raw_transaction_hash, json_rpc_named_arguments)
    end
  end

  describe "fetch_transaction_receipt_by_hash/2" do
    test "returns transaction receipt data for a valid transaction hash",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      transaction_hash = "0x3078313131313131313131313131313131313131313131313131313131313131"
      raw_transaction_hash = "3078313131313131313131313131313131313131313131313131313131313131" |> Base.decode16!()

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn
          %{id: _id, method: "eth_getTransactionReceipt", params: [^transaction_hash]}, _options ->
            {:ok,
             %{
               "transactionHash" => transaction_hash
             }}

          %{id: _id, method: "eth_getTransactionReceipt", params: [%Hash{bytes: ^raw_transaction_hash}]}, _options ->
            {:ok,
             %{
               "transactionHash" => transaction_hash
             }}
        end
      )

      assert %{"transactionHash" => ^transaction_hash} =
               ZksyncRpc.fetch_transaction_receipt_by_hash(raw_transaction_hash, json_rpc_named_arguments)
    end
  end
end
