# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenBalance.CurrentTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Repo
  alias Indexer.Fetcher.TokenBalance.Current, as: TokenBalanceCurrent

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  describe "run/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      TokenBalanceCurrent.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "returns :ok for a batch that was imported and broadcasted, so it is not retried" do
      Subscriber.to(:address_current_token_balances, :realtime)

      address = insert(:address)
      %{contract_address_hash: token_contract_address_hash} = insert(:token)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}],
                                                _options ->
        {:ok, [%{id: id, jsonrpc: "2.0", result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"}]}
      end)

      assert TokenBalanceCurrent.run(
               [{address.hash.bytes, token_contract_address_hash.bytes, 1, "ERC-20", nil, 0}],
               nil
             ) == :ok

      assert_receive {:chain_event, :address_current_token_balances, :realtime, [%CurrentTokenBalance{}]}

      assert %CurrentTokenBalance{value: value, value_fetched_at: value_fetched_at} = Repo.one(CurrentTokenBalance)
      assert value == Decimal.new(1_000_000_000_000_000_000_000_000)
      refute is_nil(value_fetched_at)
    end
  end

  describe "import_token_balances/1" do
    test "returns :ok when the current token balances were imported and broadcasted" do
      Subscriber.to(:address_current_token_balances, :realtime)

      address = insert(:address)
      %{contract_address_hash: token_contract_address_hash} = insert(:token)

      params = [
        %{
          address_hash: to_string(address.hash),
          token_contract_address_hash: to_string(token_contract_address_hash),
          block_number: 1,
          token_type: "ERC-20",
          token_id: nil,
          value: Decimal.new(100),
          value_fetched_at: DateTime.utc_now()
        }
      ]

      assert TokenBalanceCurrent.import_token_balances(params) == :ok

      assert_receive {:chain_event, :address_current_token_balances, :realtime, [%CurrentTokenBalance{}]}
    end

    test "returns :ok when there is nothing to import" do
      assert TokenBalanceCurrent.import_token_balances([]) == :ok
    end

    test "returns :error when the current token balances have invalid data" do
      %{contract_address_hash: token_contract_address_hash} = insert(:token)

      params = [
        %{
          address_hash: nil,
          token_contract_address_hash: to_string(token_contract_address_hash),
          block_number: nil,
          token_type: nil,
          token_id: nil,
          value: nil,
          value_fetched_at: nil
        }
      ]

      assert TokenBalanceCurrent.import_token_balances(params) == :error
    end
  end
end
