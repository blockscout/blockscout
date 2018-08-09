defmodule Indexer.AddressBalanceFetcherTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow BalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
  import Mox

  alias Explorer.Chain.{Address, Balance, Hash, Wei}
  alias Indexer.{BalanceFetcher, AddressBalanceFetcherCase}

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    :ok
  end

  describe "init/1" do
    test "fetches unfetched Block miner balance", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      %{block_number: block_number, fetched_balance: fetched_balance, miner_hash_data: miner_hash_data} =
        case variant do
          EthereumJSONRPC.Geth ->
            %{
              block_number: 201_480,
              fetched_balance: 6_301_752_965_671_077_173,
              miner_hash_data: "0xe6a7a1d47ff21b6321162aea7c6cb457d5476bca"
            }

          EthereumJSONRPC.Parity ->
            %{
              block_number: 34,
              fetched_balance: 252_460_834_000_000_000_000_000_000,
              miner_hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block_quantity = integer_to_quantity(block_number)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance", params: [^miner_hash_data, ^block_quantity]}],
                                _options ->
          {:ok, [%{id: id, result: integer_to_quantity(fetched_balance)}]}
        end)
      end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: block_number)

      assert miner.fetched_balance == nil
      assert miner.fetched_balance_block_number == nil

      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert fetched_address.fetched_balance_block_number == block.number
    end

    test "fetches unfetched addresses when less than max batch size", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      %{block_number: block_number, fetched_balance: fetched_balance, miner_hash_data: miner_hash_data} =
        case variant do
          EthereumJSONRPC.Geth ->
            %{
              block_number: 201_480,
              fetched_balance: 6_301_752_965_671_077_173,
              miner_hash_data: "0xe6a7a1d47ff21b6321162aea7c6cb457d5476bca"
            }

          EthereumJSONRPC.Parity ->
            %{
              block_number: 34,
              fetched_balance: 252_460_834_000_000_000_000_000_000,
              miner_hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block_quantity = integer_to_quantity(block_number)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance", params: [^miner_hash_data, ^block_quantity]}],
                                _options ->
          {:ok, [%{id: id, result: integer_to_quantity(fetched_balance)}]}
        end)
      end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: block_number)

      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments, max_batch_size: 2)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert fetched_address.fetched_balance_block_number == block.number
    end
  end

  describe "async_fetch_balances/1" do
    test "fetches balances for address_hashes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      variant = Keyword.fetch!(json_rpc_named_arguments, :variant)

      %{block_number: block_number, fetched_balance: fetched_balance, hash: hash} =
        case variant do
          EthereumJSONRPC.Geth ->
            %{
              block_number: 201_480,
              fetched_balance: 6_301_752_965_671_077_173,
              hash: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes: <<230, 167, 161, 212, 127, 242, 27, 99, 33, 22, 42, 234, 124, 108, 180, 87, 213, 71, 107, 202>>
              }
            }

          EthereumJSONRPC.Parity ->
            %{
              block_number: 34,
              fetched_balance: 252_460_834_000_000_000_000_000_000,
              hash: %Explorer.Chain.Hash{
                byte_count: 20,
                bytes:
                  <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
              }
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        block_quantity = integer_to_quantity(block_number)
        hash_data = to_string(hash)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance", params: [^hash_data, ^block_quantity]}],
                                _options ->
          {:ok, [%{id: id, result: integer_to_quantity(fetched_balance)}]}
        end)
      end

      AddressBalanceFetcherCase.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert :ok = BalanceFetcher.async_fetch_balances([%{address_hash: hash, block_number: block_number}])

      address =
        wait(fn ->
          Repo.get!(Address, hash)
        end)

      assert address.fetched_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert address.fetched_balance_block_number == block_number
    end
  end

  describe "run/2" do
    test "duplicate address hashes uses all block_quantity", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      %{balance_by_block_number: expected_balance_by_block_number, hash_data: hash_data} =
        case Keyword.fetch!(json_rpc_named_arguments, :variant) do
          EthereumJSONRPC.Geth ->
            %{
              balance_by_block_number: %{
                1 => 5_000_000_000_000_000_000,
                2 => 5_000_000_000_000_000_000
              },
              hash_data: "0x05a56e2d52c817161883f50c441c3228cfe54d9f"
            }

          EthereumJSONRPC.Parity ->
            %{
              balance_by_block_number: %{
                1 => 252_460_801_000_000_000_000_000_000,
                2 => 252_460_802_000_000_000_000_000_000
              },
              hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            }

          variant ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      block_quantities =
        expected_balance_by_block_number
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(&integer_to_quantity/1)

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        expected_requests =
          block_quantities
          |> Stream.with_index()
          |> Enum.map(fn {block_quantity, index} ->
            %{id: index, jsonrpc: "2.0", method: "eth_getBalance", params: [hash_data, block_quantity]}
          end)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn ^expected_requests, _options ->
          {:ok,
           Enum.map(expected_requests, fn %{id: id, params: [_, block_quantity]} ->
             %{
               id: id,
               result:
                 expected_balance_by_block_number
                 |> Map.fetch!(quantity_to_integer(block_quantity))
                 |> integer_to_quantity()
             }
           end)}
        end)
      end

      params_list = Enum.map(block_quantities, &%{block_quantity: &1, hash_data: hash_data})

      case BalanceFetcher.run(params_list, 0, json_rpc_named_arguments) do
        :ok ->
          balances = Repo.all(from(balance in Balance, where: balance.address_hash == ^hash_data))

          assert Enum.count(balances) == 2

          balance_by_block_number =
            Enum.into(balances, %{}, fn %Balance{block_number: block_number} = balance -> {block_number, balance} end)

          Enum.each(expected_balance_by_block_number, fn {block_number, expected_balance} ->
            expected_value = %Explorer.Chain.Wei{value: Decimal.new(expected_balance)}

            assert %Balance{value: ^expected_value} = balance_by_block_number[block_number]
          end)

          fetched_address = Repo.one!(from(address in Address, where: address.hash == ^hash_data))

          {expected_fetched_balance_block_number, expected_fetched_balance_value} =
            Enum.max_by(expected_balance_by_block_number, fn {block_number, _} -> block_number end)

          expected_fetched_balance = %Explorer.Chain.Wei{value: Decimal.new(expected_fetched_balance_value)}

          assert fetched_address.fetched_balance == expected_fetched_balance
          assert fetched_address.fetched_balance_block_number == expected_fetched_balance_block_number

        other ->
          # not all nodes behind the `https://mainnet.infura.io` pool are fully-synced.  Node that aren't fully-synced
          # won't have historical address balances.
          assert {:retry, ^params_list} = other
      end
    end

    test "duplicate params retry unique params", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      hash_data = "0x000000000000000000000000000000000"

      if json_rpc_named_arguments[:transport] == EthereumJSONRPC.Mox do
        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [%{id: id, method: "eth_getBalance", params: [^hash_data, "0x1"]}], _options ->
          {:ok, [%{id: id, error: %{code: 404, message: "Not Found"}}]}
        end)
      end

      assert BalanceFetcher.run(
               [%{block_quantity: "0x1", hash_data: hash_data}, %{block_quantity: "0x1", hash_data: hash_data}],
               0,
               json_rpc_named_arguments
             ) ==
               {:retry,
                [
                  %{
                    block_quantity: "0x1",
                    hash_data: "0x000000000000000000000000000000000"
                  }
                ]}
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end
end
