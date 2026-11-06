# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Indexer.Fetcher.Token, as: TokenFetcher

  setup :verify_on_exit!

  describe "init/3" do
    test "returns uncataloged tokens", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:token, cataloged: true)
      %Token{contract_address_hash: uncatalog_address} = insert(:token, cataloged: false)

      assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == [uncatalog_address]
    end

    test "skips uncataloged tokens whose metadata refetch is scheduled in the future", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      insert(:token, cataloged: false, metadata_refetch_after: Timex.shift(Timex.now(), hours: 1))

      %Token{contract_address_hash: due_address} =
        insert(:token, cataloged: false, metadata_refetch_after: Timex.shift(Timex.now(), hours: -1))

      assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == [due_address]
    end
  end

  describe "run/3" do
    test "catalogs tokens that haven't been cataloged", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          1,
          fn requests, _opts ->
            {:ok,
             Enum.map(requests, fn
               %{id: id, method: "eth_call", params: [%{data: "0x313ce567", to: _}, "latest"]} ->
                 %{
                   id: id,
                   result: "0x0000000000000000000000000000000000000000000000000000000000000012"
                 }

               %{id: id, method: "eth_call", params: [%{data: "0x06fdde03", to: _}, "latest"]} ->
                 %{
                   id: id,
                   result:
                     "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
                 }

               %{id: id, method: "eth_call", params: [%{data: "0x95d89b41", to: _}, "latest"]} ->
                 %{
                   id: id,
                   result:
                     "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003424e540000000000000000000000000000000000000000000000000000000000"
                 }

               %{id: id, method: "eth_call", params: [%{data: "0x18160ddd", to: _}, "latest"]} ->
                 %{
                   id: id,
                   result: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000"
                 }
             end)}
          end
        )

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        expected_supply = Decimal.new(1_000_000_000_000_000_000)

        decimals_expected = Decimal.new(18)

        assert {:ok,
                %Token{
                  name: "Bancor",
                  symbol: "BNT",
                  total_supply: ^expected_supply,
                  decimals: ^decimals_expected,
                  cataloged: true
                }} = Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "backs off a token whose getters fail for a non-contract reason instead of re-queueing it at once", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # `:token_functions_reader_max_retries` batches of getters, every one failing with a transport-like error
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          Application.get_env(:explorer, :token_functions_reader_max_retries),
          fn requests, _opts ->
            {:ok,
             Enum.map(requests, fn %{id: id, method: "eth_call"} ->
               %{id: id, error: %{code: -32015, data: "something", message: "network error"}, jsonrpc: "2.0"}
             end)}
          end
        )

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok,
                %Token{
                  cataloged: false,
                  skip_metadata: nil,
                  metadata_retries_count: 1,
                  metadata_refetch_after: %DateTime{} = refetch_after
                }} = Chain.token_from_address_hash(contract_address_hash)

        assert DateTime.compare(refetch_after, DateTime.utc_now()) == :gt

        # the token is not handed back to the fetcher until the backoff has passed
        assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == []
      end
    end

    test "grows the backoff with every failed attempt", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      token =
        insert(:token,
          name: nil,
          symbol: nil,
          total_supply: nil,
          decimals: nil,
          cataloged: false,
          metadata_retries_count: 1,
          metadata_refetch_after: Timex.shift(Timex.now(), hours: -1)
        )

      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          Application.get_env(:explorer, :token_functions_reader_max_retries),
          fn requests, _opts ->
            {:ok,
             Enum.map(requests, fn %{id: id, method: "eth_call"} ->
               %{id: id, error: %{code: -32015, data: "something", message: "network error"}, jsonrpc: "2.0"}
             end)}
          end
        )

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{cataloged: false, metadata_retries_count: 2, metadata_refetch_after: second_refetch_after}} =
                 Chain.token_from_address_hash(contract_address_hash)

        coef = Application.get_env(:indexer, TokenFetcher)[:exp_timeout_coeff]
        first_backoff_seconds = floor(coef * :math.exp(1))
        second_backoff_seconds = floor(coef * :math.exp(2))

        assert DateTime.diff(second_refetch_after, DateTime.utc_now()) > first_backoff_seconds
        assert DateTime.diff(second_refetch_after, DateTime.utc_now()) <= second_backoff_seconds
      end
    end

    test "still marks a token with contract failures as skip_metadata", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          Application.get_env(:explorer, :token_functions_reader_max_retries),
          fn requests, _opts ->
            {:ok,
             Enum.map(requests, fn %{id: id, method: "eth_call"} ->
               %{id: id, error: %{code: -32015, data: "something", message: "execution reverted"}, jsonrpc: "2.0"}
             end)}
          end
        )

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{cataloged: true, skip_metadata: true, metadata_refetch_after: nil}} =
                 Chain.token_from_address_hash(contract_address_hash)

        assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == []
      end
    end
  end
end
