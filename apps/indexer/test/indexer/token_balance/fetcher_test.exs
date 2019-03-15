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
               {address_hash_bytes, token_contract_address_hash_bytes, block_number, 0}
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
        fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               id: id,
               jsonrpc: "2.0",
               result: "0x00000000000000000000000000000000000000000000d3c21bcecceda1000000"
             }
           ]}
        end
      )

      assert TokenBalance.Fetcher.run(
               [{address_hash_bytes, token_contract_address_hash_bytes, block_number, 0}],
               nil
             ) == :ok

      token_balance_updated = Explorer.Repo.get_by(Address.TokenBalance, address_hash: address_hash)

      assert token_balance_updated.value == Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value_fetched_at != nil
    end

    test "does not try to fetch the token balance again if the retry is over" do
      max_retries = 3

      Application.put_env(:indexer, :token_balance_max_retries, max_retries)

      token_balance_a = insert(:token_balance, value_fetched_at: nil, value: nil)
      token_balance_b = insert(:token_balance, value_fetched_at: nil, value: nil)

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        1,
        fn [%{id: id, method: "eth_call", params: [%{data: _, to: _}, _]}], _options ->
          {:ok,
           [
             %{
               error: %{code: -32015, data: "Reverted 0x", message: "VM execution error."},
               id: id,
               jsonrpc: "2.0"
             }
           ]}
        end
      )

      token_balances = [
        {
          token_balance_a.address_hash.bytes,
          token_balance_a.token_contract_address_hash.bytes,
          token_balance_a.block_number,
          # this token balance must be ignored
          max_retries
        },
        {
          token_balance_b.address_hash.bytes,
          token_balance_b.token_contract_address_hash.bytes,
          token_balance_b.block_number,
          # this token balance still have to be retried
          max_retries - 2
        }
      ]

      assert TokenBalance.Fetcher.run(token_balances, nil) == :ok
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

    test "insert the missing address, import the token balances and return :ok when the address does not exist yet" do
      contract = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash)
        }
      ]

      {:ok, address_hash} = Explorer.Chain.string_to_address_hash("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
      assert TokenBalance.Fetcher.import_token_balances(token_balances_params) == :ok
      assert {:ok, _} = Explorer.Chain.hash_to_address(address_hash)
    end

    test "import the token balances and return :ok when there are multiple balances for the same address on the batch" do
      contract = insert(:token)
      contract2 = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash)
        },
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract2.contract_address_hash)
        }
      ]

      assert TokenBalance.Fetcher.import_token_balances(token_balances_params) == :ok
    end
  end
end
