defmodule Indexer.TokenBalance.FetcherTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{Address, Hash}
  alias Indexer.TokenBalance

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  describe "init/3" do
    test "returns unfetched token balances" do
      %Address.TokenBalance{
        address_hash: %Hash{bytes: address_hash_bytes},
        token_contract_address_hash: %Hash{bytes: token_contract_address_hash_bytes},
        block_number: block_number
      } = insert(:token_balance, block_number: 1_000, value_fetched_at: nil)

      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      assert TokenBalance.Fetcher.init([], &[&1 | &2], nil) == [
               {address_hash_bytes, token_contract_address_hash_bytes, block_number}
             ]
    end
  end

  describe "run/3" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      TokenBalance.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "imports the given token balances" do
      %Address.TokenBalance{
        address_hash: %Hash{bytes: address_hash_bytes} = address_hash,
        token_contract_address_hash: %Hash{bytes: token_contract_address_hash_bytes},
        block_number: block_number
      } = insert(:token_balance, value_fetched_at: nil, value: nil)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [%{id: _, method: _, params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: "balanceOf",
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      assert TokenBalance.Fetcher.run([{address_hash_bytes, token_contract_address_hash_bytes, block_number}], nil) ==
               :ok

      token_balance_updated = Explorer.Repo.get_by(Address.TokenBalance, address_hash: address_hash)

      assert token_balance_updated.value == Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value_fetched_at != nil
    end
  end

  describe "import_token_balances/1" do
    test "ignores when it receives a empty list" do
      assert TokenBalance.Fetcher.import_token_balances([]) == :ok
    end

    test "returns :error when the token balances has invalid data" do
      token_balance = insert(:token_balance, value_fetched_at: nil, value: nil)

      token_balances_params = [
        %{
          address_hash: nil,
          block_number: nil,
          token_contract_address_hash: to_string(token_balance.token_contract_address_hash),
          value: nil,
          value_fetched_at: nil
        }
      ]

      assert TokenBalance.Fetcher.import_token_balances(token_balances_params) == :error
    end
  end
end
