# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Fetcher.ContractCreationBlockTest do
  use ExUnit.Case, async: true

  import Mox

  alias Explorer.Chain.Fetcher.ContractCreationBlock

  setup :verify_on_exit!

  @address "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
  @json_rpc_named_arguments [
    transport: EthereumJSONRPC.Mox,
    transport_options: [],
    variant: EthereumJSONRPC.Nethermind
  ]

  describe "find/2" do
    test "finds the creation block when it is right from the middle of the range" do
      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock("0x2", "0x0")
      |> eth_get_transaction_count_mock("0x3", "0x1")

      assert {:ok, 3} = ContractCreationBlock.find(@address, opts(4))
    end

    test "finds the creation block when it is in the middle of the range" do
      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock("0x2", "0x1")
      |> eth_get_transaction_count_mock("0x1", "0x0")

      assert {:ok, 2} = ContractCreationBlock.find(@address, opts(4))
    end

    test "finds the creation block when it is left from the middle of the range" do
      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock("0x2", "0x1")
      |> eth_get_transaction_count_mock("0x1", "0x1")
      |> eth_get_transaction_count_mock("0x0", "0x0")

      assert {:ok, 1} = ContractCreationBlock.find(@address, opts(4))
    end

    test "retries after a JSON RPC error and succeeds" do
      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_error_mock("0x2")
      |> eth_get_transaction_count_mock("0x2", "0x0")
      |> eth_get_transaction_count_mock("0x3", "0x1")

      assert {:ok, 3} = ContractCreationBlock.find(@address, opts(4))
    end

    test "gives up after max_retries JSON RPC errors" do
      mox = EthereumJSONRPC.Mox

      Enum.reduce(1..3, mox, fn _, acc -> eth_get_transaction_count_error_mock(acc, "0x2") end)

      assert {:error, :max_retries} = ContractCreationBlock.find(@address, opts(4, max_retries: 2))
    end

    test "converges on the right bound when the nonce is 0 at every block" do
      # Pre-Spurious-Dragon contracts and some predeploys never get a nonce, so the
      # search cannot distinguish them from a contract created in the last block.
      # Callers must validate the result (see `Explorer.SmartContract.CreationDataResolver`).
      EthereumJSONRPC.Mox
      |> eth_get_transaction_count_mock("0x2", "0x0")
      |> eth_get_transaction_count_mock("0x3", "0x0")
      |> eth_get_transaction_count_mock("0x3", "0x0")

      assert {:ok, 4} = ContractCreationBlock.find(@address, opts(4))
    end
  end

  defp opts(max_block_number, extra \\ []) do
    Keyword.merge(
      [
        max_block_number: max_block_number,
        retry_delay_ms: 0,
        json_rpc_named_arguments: @json_rpc_named_arguments
      ],
      extra
    )
  end

  defp eth_get_transaction_count_mock(mox, block_number, nonce) do
    address = @address

    expect(mox, :json_rpc, fn %{
                                id: _id,
                                jsonrpc: "2.0",
                                method: "eth_getTransactionCount",
                                params: [^address, ^block_number]
                              },
                              _ ->
      {:ok, nonce}
    end)
  end

  defp eth_get_transaction_count_error_mock(mox, block_number) do
    address = @address

    expect(mox, :json_rpc, fn %{
                                id: _id,
                                jsonrpc: "2.0",
                                method: "eth_getTransactionCount",
                                params: [^address, ^block_number]
                              },
                              _ ->
      {:error, %{code: -32000, message: "missing trie node"}}
    end)
  end
end
