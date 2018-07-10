defmodule Indexer.AddressBalanceFetcherTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow AddressBalanceFetcher's self-send to have
  # connection allowed immediately.
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{Address, Hash, Wei}
  alias Indexer.{AddressBalanceFetcher, AddressBalanceFetcherCase}

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    %{variant: EthereumJSONRPC.config(:variant)}
  end

  describe "init/1" do
    test "fetches unfetched Block miner balance", %{variant: variant} do
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

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)

      assert miner.fetched_balance == nil
      assert miner.fetched_balance_block_number == nil

      AddressBalanceFetcherCase.start_supervised!()

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_balance))
          )
        end)

      assert fetched_address.fetched_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert fetched_address.fetched_balance_block_number == block.number
    end

    test "fetches unfetched addresses when less than max batch size", %{variant: variant} do
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

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)

      AddressBalanceFetcherCase.start_supervised!(max_batch_size: 2)

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
    test "fetches balances for address_hashes", %{variant: variant} do
      AddressBalanceFetcherCase.start_supervised!()

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

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      assert :ok = AddressBalanceFetcher.async_fetch_balances([%{block_number: block_number, hash: hash}])

      address =
        wait(fn ->
          Repo.get!(Address, hash)
        end)

      assert address.fetched_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert address.fetched_balance_block_number == block_number
    end
  end

  describe "run/2" do
    @tag capture_log: true
    test "duplicate address hashes the max block_quantity", %{variant: variant} do
      %{fetched_balance: fetched_balance, hash_data: hash_data} =
        case variant do
          EthereumJSONRPC.Geth ->
            %{
              fetched_balance: 5_000_000_000_000_000_000,
              hash_data: "0x05a56e2d52c817161883f50c441c3228cfe54d9f"
            }

          EthereumJSONRPC.Parity ->
            %{
              fetched_balance: 252_460_802_000_000_000_000_000_000,
              hash_data: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
            }

          _ ->
            raise ArgumentError, "Unsupported variant (#{variant})"
        end

      case AddressBalanceFetcher.run(
             [%{block_quantity: "0x1", hash_data: hash_data}, %{block_quantity: "0x2", hash_data: hash_data}],
             0
           ) do
        :ok ->
          fetched_address = Repo.one!(from(address in Address, where: address.hash == ^hash_data))

          assert fetched_address.fetched_balance == %Explorer.Chain.Wei{
                   value: Decimal.new(fetched_balance)
                 }

          assert fetched_address.fetched_balance_block_number == 2

        other ->
          # not all nodes behind the `https://mainnet.infura.io` pool are fully-synced.  Node that aren't fully-synced
          # won't have historical address balances.
          assert {:retry, [%{block_quantity: "0x2", hash_data: ^hash_data}]} = other
      end
    end

    test "duplicate address hashes only retry max block_quantity" do
      hash_data = "0x000000000000000000000000000000000"

      assert AddressBalanceFetcher.run(
               [%{block_quantity: "0x1", hash_data: hash_data}, %{block_quantity: "0x2", hash_data: hash_data}],
               0
             ) ==
               {:retry,
                [
                  %{
                    block_quantity: "0x2",
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
