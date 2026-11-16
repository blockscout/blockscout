# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.{Token, TokenTransfer}
  alias Explorer.Repo
  alias Indexer.Fetcher.Token, as: TokenFetcher

  setup :verify_on_exit!

  describe "init/3" do
    test "returns uncataloged tokens", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:token, cataloged: true)
      %Token{contract_address_hash: uncatalog_address} = insert(:token, cataloged: false)

      assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == [uncatalog_address]
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

    test "catalogs a token whose bytecode halts the EVM with skip_metadata so it is not asked again", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # every getter fails, and each is retried `:token_functions_reader_max_retries` (3) times
        expect(
          EthereumJSONRPC.Mox,
          :json_rpc,
          3,
          fn requests, _opts ->
            {:ok,
             Enum.map(requests, fn %{id: id, method: "eth_call"} ->
               %{id: id, error: %{code: -32003, message: "EVM error: StackUnderflow"}, jsonrpc: "2.0"}
             end)}
          end
        )

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{cataloged: true, skip_metadata: true, name: nil}} =
                 Chain.token_from_address_hash(contract_address_hash)

        assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == []
      end
    end

    test "finishes the ERC-404 conversion of a token left uncataloged by a failed attempt", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      # a failed attempt retypes the token before converting its transfers
      token = insert(:token, type: "ERC-404", decimals: 18, cataloged: false)
      contract_address_hash = token.contract_address_hash
      token_address = Repo.preload(token, :contract_address).contract_address

      erc20_transfer =
        insert(:token_transfer,
          from_address: insert(:address),
          token_contract_address: token_address,
          token_type: "ERC-20",
          amount: Decimal.new(5),
          token_ids: nil
        )

      # the current token balances are retyped last
      insert(:address_current_token_balance,
        token_contract_address_hash: contract_address_hash,
        token_type: "ERC-721",
        value: 1
      )

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn %{id: id} ->
             %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}
           end)}
        end)

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{type: "ERC-404", cataloged: true}} = Chain.token_from_address_hash(contract_address_hash)

        assert %TokenTransfer{token_type: "ERC-404", amount: nil, token_ids: [], amounts: [amount]} =
                 Repo.get_by(TokenTransfer,
                   transaction_hash: erc20_transfer.transaction_hash,
                   block_hash: erc20_transfer.block_hash,
                   log_index: erc20_transfer.log_index
                 )

        assert Decimal.equal?(amount, 5)

        assert [%CurrentTokenBalance{token_type: "ERC-404"}] = Repo.all(CurrentTokenBalance)
      end
    end

    test "retries the ERC-404 getters, then catalogs the token as an ERC-721 one when the node keeps failing", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, type: "ERC-721", decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # the metadata getters, then `erc20TotalSupply()` and `erc721TotalSupply()`
        # `:token_functions_reader_max_retries` (3) times
        expect(EthereumJSONRPC.Mox, :json_rpc, 4, fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, params: [%{data: data}, _]} when data in ["0x89fb4c66", "0xc5ab3ba6"] ->
               %{id: id, error: %{code: -32000, message: "header not found"}, jsonrpc: "2.0"}

             %{id: id} ->
               %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}
           end)}
        end)

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        decimals = Decimal.new(18)

        assert {:ok, %Token{type: "ERC-721", decimals: ^decimals, cataloged: true}} =
                 Chain.token_from_address_hash(contract_address_hash)

        # an uncataloged token would be picked up again right away
        assert TokenFetcher.init([], &[&1 | &2], json_rpc_named_arguments) == []
      end
    end

    test "asks the ERC-404 getters of an ERC-721 token when the node fails decimals()", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, type: "ERC-721", name: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # the metadata getters, two retries of `decimals()`, then the ERC-404 getters
        expect(EthereumJSONRPC.Mox, :json_rpc, 4, fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, params: [%{data: "0x313ce567"}, _]} ->
               %{id: id, error: %{code: -32000, message: "header not found"}, jsonrpc: "2.0"}

             %{id: id, params: [%{data: data}, _]} when data in ["0x89fb4c66", "0xc5ab3ba6"] ->
               %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}

             %{id: id, params: [%{data: "0x18160ddd"}, _]} ->
               %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}

             %{id: id} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }
           end)}
        end)

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{type: "ERC-404", name: "Bancor", decimals: nil, cataloged: true}} =
                 Chain.token_from_address_hash(contract_address_hash)
      end
    end

    test "catalogs an ERC-721 token whose contract reverts decimals()", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      token = insert(:token, type: "ERC-721", name: nil, decimals: nil, cataloged: false)
      contract_address_hash = token.contract_address_hash

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        # the metadata getters, then two retries of `decimals()`; no ERC-404 getters
        expect(EthereumJSONRPC.Mox, :json_rpc, 3, fn requests, _opts ->
          {:ok,
           Enum.map(requests, fn
             %{id: id, params: [%{data: "0x313ce567"}, _]} ->
               %{id: id, error: %{code: -32015, data: "0x", message: "execution reverted"}, jsonrpc: "2.0"}

             %{id: id, params: [%{data: "0x18160ddd"}, _]} ->
               %{id: id, result: "0x0000000000000000000000000000000000000000000000000000000000000012"}

             %{id: id} ->
               %{
                 id: id,
                 result:
                   "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000642616e636f720000000000000000000000000000000000000000000000000000"
               }
           end)}
        end)

        assert TokenFetcher.run([contract_address_hash], json_rpc_named_arguments) == :ok

        assert {:ok, %Token{type: "ERC-721", name: "Bancor", cataloged: true}} =
                 Chain.token_from_address_hash(contract_address_hash)
      end
    end
  end
end
