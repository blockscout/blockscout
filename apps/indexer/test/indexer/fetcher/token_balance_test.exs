defmodule Indexer.Fetcher.TokenBalanceTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{Address, Hash}
  alias Indexer.Fetcher.TokenBalance

  @moduletag :capture_log

  setup :verify_on_exit!
  setup :set_mox_global

  describe "init/3" do
    test "returns unfetched token balances" do
      %Address.TokenBalance{
        address_hash: %Hash{bytes: address_hash_bytes},
        token_contract_address_hash: %Hash{bytes: token_contract_address_hash_bytes},
        block_number: _block_number
      } = insert(:token_balance, block_number: 1_000, value_fetched_at: nil)

      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      assert TokenBalance.init([], &[&1 | &2], nil) == [
               {address_hash_bytes, token_contract_address_hash_bytes, 1000, "ERC-20", nil, 0}
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

      assert TokenBalance.run(
               [{address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}],
               nil
             ) == :ok

      token_balance_updated = Explorer.Repo.get_by(Address.TokenBalance, address_hash: address_hash)

      assert token_balance_updated.value == Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value_fetched_at != nil
    end

    test "imports the given token balances from 2nd retry" do
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
               error: %{code: -32015, message: "VM execution error.", data: ""}
             }
           ]}
        end
      )

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

      assert TokenBalance.run(
               [{address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}],
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

      token_balances = [
        {
          token_balance_a.address_hash.bytes,
          token_balance_a.token_contract_address_hash.bytes,
          "ERC-20",
          nil,
          token_balance_a.block_number,
          # this token balance must be ignored
          max_retries
        },
        {
          token_balance_b.address_hash.bytes,
          token_balance_b.token_contract_address_hash.bytes,
          "ERC-20",
          nil,
          token_balance_b.block_number,
          # this token balance still have to be retried
          max_retries - 2
        }
      ]

      assert TokenBalance.run(token_balances, nil) == :ok
    end

    test "fetches duplicate params only once" do
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

      assert TokenBalance.run(
               [
                 {address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0},
                 {address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert 1 =
               from(tb in Address.TokenBalance, where: tb.address_hash == ^address_hash)
               |> Explorer.Repo.aggregate(:count, :id)
    end
  end

  describe "import_token_balances/1" do
    test "ignores when it receives a empty list" do
      assert TokenBalance.import_token_balances([]) == :ok
    end

    test "returns :error when the token balances has invalid data" do
      token_balance = insert(:token_balance, value_fetched_at: nil, value: nil)

      token_balances_params = [
        %{
          address_hash: nil,
          block_number: nil,
          token_contract_address_hash: to_string(token_balance.token_contract_address_hash),
          token_id: nil,
          value: nil,
          token_type: nil,
          value_fetched_at: nil
        }
      ]

      assert TokenBalance.import_token_balances(token_balances_params) == :error
    end

    test "insert the missing address, import the token balances and return :ok when the address does not exist yet" do
      contract = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash),
          token_type: "ERC-20",
          token_id: nil
        }
      ]

      {:ok, address_hash} = Explorer.Chain.string_to_address_hash("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
      assert TokenBalance.import_token_balances(token_balances_params) == :ok
      assert {:ok, _} = Explorer.Chain.hash_to_address(address_hash)
    end

    test "import the token balances and return :ok when there are multiple balances for the same address on the batch (ERC-20)" do
      contract = insert(:token)
      contract2 = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash),
          token_id: nil,
          token_type: "ERC-20"
        },
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract2.contract_address_hash),
          token_id: nil,
          token_type: "ERC-20"
        }
      ]

      assert TokenBalance.import_token_balances(token_balances_params) == :ok
    end

    test "import the token balances and return :ok when there are multiple balances for the same address on the batch (ERC-1155)" do
      contract = insert(:token)
      contract2 = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash),
          token_id: 11,
          token_type: "ERC-20"
        },
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract2.contract_address_hash),
          token_id: 11,
          token_type: "ERC-1155"
        }
      ]

      assert TokenBalance.import_token_balances(token_balances_params) == :ok
    end
  end
end
