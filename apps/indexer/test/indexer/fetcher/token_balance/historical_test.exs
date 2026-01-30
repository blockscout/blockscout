defmodule Indexer.Fetcher.TokenBalance.HistoricalTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Repo
  alias Explorer.Utility.MissingBalanceOfToken
  alias Indexer.Fetcher.TokenBalance.Historical, as: TokenBalanceHistorical

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

      assert TokenBalanceHistorical.init([], &[&1 | &2], nil) == [
               {address_hash_bytes, token_contract_address_hash_bytes, 1000, "ERC-20", nil, 0}
             ]
    end

    test "omits failed balances with refetch_after in future" do
      %Address.TokenBalance{
        address_hash: %Hash{bytes: address_hash_bytes},
        token_contract_address_hash: %Hash{bytes: token_contract_address_hash_bytes},
        block_number: block_number
      } = insert(:token_balance, value_fetched_at: nil)

      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      insert(:token_balance, refetch_after: Timex.shift(Timex.now(), hours: 1))

      assert TokenBalanceHistorical.init([], &[&1 | &2], nil) == [
               {address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}
             ]
    end
  end

  describe "run/3" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      TokenBalanceHistorical.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      :ok
    end

    test "imports the given token balances" do
      Subscriber.to(:address_current_token_balances, :realtime)

      %Address.TokenBalance{
        address_hash: %Hash{bytes: address_hash_bytes} = address_hash,
        token_contract_address_hash: %Hash{bytes: token_contract_address_hash_bytes} = token_contract_address_hash,
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

      assert TokenBalanceHistorical.run(
               [{address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}],
               nil
             ) == :ok

      token_balance_updated = Repo.get_by(Address.TokenBalance, address_hash: address_hash)

      expected_value = Decimal.new(1_000_000_000_000_000_000_000_000)
      assert token_balance_updated.value == expected_value
      assert token_balance_updated.value_fetched_at != nil
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

      assert TokenBalanceHistorical.run(
               [
                 {address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0},
                 {address_hash_bytes, token_contract_address_hash_bytes, block_number, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert 1 =
               from(tb in Address.TokenBalance, where: tb.address_hash == ^address_hash)
               |> Repo.aggregate(:count, :id)
    end

    test "filters out params with tokens that doesn't implement balanceOf function" do
      address = insert(:address)
      missing_balance_of_token = insert(:missing_balance_of_token, currently_implemented: true)

      assert TokenBalanceHistorical.run(
               [
                 {address.hash.bytes, missing_balance_of_token.token_contract_address_hash.bytes,
                  missing_balance_of_token.block_number, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert Repo.all(Address.TokenBalance) == []
    end

    test "set currently_implemented: true for missing balanceOf token if balance was successfully fetched" do
      address = insert(:address)
      missing_balance_of_token = insert(:missing_balance_of_token)
      window_size = Application.get_env(:explorer, MissingBalanceOfToken)[:window_size]

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

      refute missing_balance_of_token.currently_implemented

      assert TokenBalanceHistorical.run(
               [
                 {address.hash.bytes, missing_balance_of_token.token_contract_address_hash.bytes,
                  missing_balance_of_token.block_number + window_size + 1, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert %{currently_implemented: true} = Repo.one(MissingBalanceOfToken)
    end

    test "in case of execution reverted error deletes token balance placeholders below the given number and inserts new missing balanceOf tokens" do
      address = insert(:address)
      %{contract_address_hash: token_contract_address_hash} = insert(:token)

      insert(:token_balance,
        token_contract_address_hash: token_contract_address_hash,
        address: address,
        block_number: 0,
        value_fetched_at: nil,
        value: nil
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
               error: %{code: "-32000", message: "execution reverted"}
             }
           ]}
        end
      )

      assert TokenBalanceHistorical.run(
               [
                 {address.hash.bytes, token_contract_address_hash.bytes, 1, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert %{token_contract_address_hash: ^token_contract_address_hash, block_number: 1} =
               Repo.one(MissingBalanceOfToken)

      assert Repo.all(Address.TokenBalance) == []
    end

    test "in case of other error updates the refetch_after and retries_count of token balance" do
      address = insert(:address)
      %{contract_address_hash: token_contract_address_hash} = insert(:token)

      insert(:token_balance,
        token_contract_address_hash: token_contract_address_hash,
        address: address,
        block_number: 1,
        value_fetched_at: nil,
        value: nil,
        refetch_after: nil,
        retries_count: nil
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
               error: %{code: "-32000", message: "other error"}
             }
           ]}
        end
      )

      assert TokenBalanceHistorical.run(
               [
                 {address.hash.bytes, token_contract_address_hash.bytes, 1, "ERC-20", nil, 0}
               ],
               nil
             ) == :ok

      assert %{retries_count: 1, refetch_after: refetch_after} = Repo.one(Address.TokenBalance)
      refute is_nil(refetch_after)
    end
  end

  describe "import_token_balances/1" do
    test "ignores when it receives a empty list" do
      assert TokenBalanceHistorical.import_token_balances([]) == :ok
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

      assert TokenBalanceHistorical.import_token_balances(token_balances_params) == :error
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
      assert TokenBalanceHistorical.import_token_balances(token_balances_params) == :ok
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

      assert TokenBalanceHistorical.import_token_balances(token_balances_params) == :ok
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
          token_id: nil,
          value: 100_500,
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

      assert TokenBalanceHistorical.import_token_balances(token_balances_params) == :ok
    end

    test "import ERC-404 token balances and return :ok" do
      contract = insert(:token)
      insert(:block, number: 19999)

      token_balances_params = [
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash),
          token_id: 11,
          token_type: "ERC-404"
        },
        %{
          address_hash: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
          block_number: 19999,
          token_contract_address_hash: to_string(contract.contract_address_hash),
          token_id: nil,
          value: 100_500,
          token_type: "ERC-404"
        }
      ]

      assert TokenBalanceHistorical.import_token_balances(token_balances_params) == :ok
    end
  end
end
