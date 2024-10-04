defmodule Indexer.Fetcher.CoinBalance.CatchupTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import EthereumJSONRPC, only: [integer_to_quantity: 1, quantity_to_integer: 1]
  import Mox

  alias Explorer.Chain.{Address, Hash, Wei}
  alias Explorer.Chain.Cache.BlockNumber
  alias Indexer.Fetcher.CoinBalance.Catchup, as: CoinBalanceCatchup

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    initial_config = Application.get_env(:explorer, Explorer.Chain.Cache.BlockNumber)
    Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, enabled: true)

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Cache.BlockNumber, initial_config)
    end)

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

          EthereumJSONRPC.Nethermind ->
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

        res = eth_block_number_fake_response(block_quantity)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: [^block_quantity, true]
                                  }
                                ],
                                _ ->
          {:ok, [res]}
        end)
      end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: block_number)

      assert miner.fetched_coin_balance == nil
      assert miner.fetched_coin_balance_block_number == nil

      CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_coin_balance))
          )
        end)

      assert fetched_address.fetched_coin_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert fetched_address.fetched_coin_balance_block_number == block.number
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

          EthereumJSONRPC.Nethermind ->
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

        res = eth_block_number_fake_response(block_quantity)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: [^block_quantity, true]
                                  }
                                ],
                                _ ->
          {:ok, [res]}
        end)
      end

      {:ok, miner_hash} = Hash.Address.cast(miner_hash_data)
      miner = insert(:address, hash: miner_hash)
      block = insert(:block, miner: miner, number: block_number)
      insert(:unfetched_balance, address_hash: miner.hash, block_number: block_number)

      CoinBalanceCatchup.Supervisor.Case.start_supervised!(
        json_rpc_named_arguments: json_rpc_named_arguments,
        max_batch_size: 2
      )

      fetched_address =
        wait(fn ->
          Repo.one!(
            from(address in Address, where: address.hash == ^miner_hash and not is_nil(address.fetched_coin_balance))
          )
        end)

      assert fetched_address.fetched_coin_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert fetched_address.fetched_coin_balance_block_number == block.number
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

          EthereumJSONRPC.Nethermind ->
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

        res = eth_block_number_fake_response(block_quantity)

        EthereumJSONRPC.Mox
        |> expect(:json_rpc, fn [
                                  %{
                                    id: 0,
                                    jsonrpc: "2.0",
                                    method: "eth_getBlockByNumber",
                                    params: [^block_quantity, true]
                                  }
                                ],
                                _ ->
          {:ok, [res]}
        end)
      end

      BlockNumber.set_max(block_number)

      CoinBalanceCatchup.Supervisor.Case.start_supervised!(json_rpc_named_arguments: json_rpc_named_arguments)

      assert :ok = CoinBalanceCatchup.async_fetch_balances([%{address_hash: hash, block_number: block_number}])

      address =
        wait(fn ->
          Repo.get!(Address, hash)
        end)

      assert address.fetched_coin_balance == %Wei{value: Decimal.new(fetched_balance)}
      assert address.fetched_coin_balance_block_number == block_number
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

          EthereumJSONRPC.Nethermind ->
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

      {:ok, %Hash{bytes: address_hash_bytes}} = Hash.Address.cast(hash_data)
      entries = Enum.map(block_quantities, &{address_hash_bytes, quantity_to_integer(&1)})

      res1 = eth_block_number_fake_response("0x1")
      res2 = eth_block_number_fake_response("0x2")

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{id: 0, jsonrpc: "2.0", method: "eth_getBlockByNumber", params: ["0x1", true]}
                              ],
                              _ ->
        {:ok, [res1]}
      end)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{id: 0, jsonrpc: "2.0", method: "eth_getBlockByNumber", params: ["0x2", true]}
                              ],
                              _ ->
        {:ok, [res2]}
      end)

      BlockNumber.set_max(2)

      case CoinBalanceCatchup.run(entries, json_rpc_named_arguments) do
        :ok ->
          balances = Repo.all(from(balance in Address.CoinBalance, where: balance.address_hash == ^hash_data))

          assert Enum.count(balances) == 2

          balance_by_block_number =
            Enum.into(balances, %{}, fn %Address.CoinBalance{block_number: block_number} = balance ->
              {block_number, balance}
            end)

          Enum.each(expected_balance_by_block_number, fn {block_number, expected_balance} ->
            expected_value = %Explorer.Chain.Wei{value: Decimal.new(expected_balance)}

            assert %Address.CoinBalance{value: ^expected_value} = balance_by_block_number[block_number]
          end)

          fetched_address = Repo.one!(from(address in Address, where: address.hash == ^hash_data))

          {expected_fetched_balance_block_number, expected_fetched_balance_value} =
            Enum.max_by(expected_balance_by_block_number, fn {block_number, _} -> block_number end)

          expected_fetched_balance = %Explorer.Chain.Wei{value: Decimal.new(expected_fetched_balance_value)}

          assert fetched_address.fetched_coin_balance == expected_fetched_balance
          assert fetched_address.fetched_coin_balance_block_number == expected_fetched_balance_block_number

        other ->
          # not all nodes behind the `https://mainnet.infura.io` pool are fully-synced.  Node that aren't fully-synced
          # won't have historical address balances.
          assert {:retry, ^entries} = other
      end
    end
  end

  describe "run/2 partial batch" do
    setup do
      %{
        json_rpc_named_arguments: [
          transport: EthereumJSONRPC.Mox,
          transport_options: [],
          # Which one does not matter, so pick one
          variant: EthereumJSONRPC.Nethermind
        ]
      }
    end

    test "retries all if no successes", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Hash{bytes: address_hash_bytes} = address_hash()
      entries = [{address_hash_bytes, block_number()}]

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_getBalance", params: [_, _]}], _ ->
        {:ok, [%{id: id, error: %{code: 1, message: "Bad"}}]}
      end)

      BlockNumber.set_max(block_number())

      assert {:retry, ^entries} = CoinBalanceCatchup.run(entries, json_rpc_named_arguments)
    end

    test "retries none if all imported and no fetch errors", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Hash{bytes: address_hash_bytes} = address_hash()
      block_number = block_number()
      entries = [{address_hash_bytes, block_number}]

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id, method: "eth_getBalance", params: [_, _]}], _ ->
        {:ok, [%{id: id, result: "0x1"}]}
      end)

      block_quantity = integer_to_quantity(block_number)
      res = eth_block_number_fake_response(block_quantity)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_getBlockByNumber",
                                  params: [^block_quantity, true]
                                }
                              ],
                              _ ->
        {:ok, [res]}
      end)

      BlockNumber.set_max(block_number)

      assert :ok = CoinBalanceCatchup.run(entries, json_rpc_named_arguments)
    end

    test "retries fetch errors if all imported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      %Hash{bytes: address_hash_bytes} = address_hash()
      bad_block_number = block_number()
      good_block_number = block_number()

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [
                                                  %{
                                                    id: first_id,
                                                    method: "eth_getBalance",
                                                    params: [_, first_block_quantity]
                                                  },
                                                  %{
                                                    id: second_id,
                                                    method: "eth_getBalance",
                                                    params: [_, _]
                                                  }
                                                ],
                                                _ ->
        responses =
          case quantity_to_integer(first_block_quantity) do
            ^good_block_number ->
              [
                %{id: first_id, result: "0x1"},
                %{id: second_id, error: %{code: 2, message: "Bad"}}
              ]

            ^bad_block_number ->
              [
                %{id: first_id, error: %{code: 1, message: "Bad"}},
                %{id: second_id, result: "0x2"}
              ]
          end

        {:ok, responses}
      end)

      good_block_quantity = integer_to_quantity(good_block_number)
      res_good = eth_block_number_fake_response(good_block_quantity)

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_getBlockByNumber",
                                  params: [^good_block_quantity, true]
                                }
                              ],
                              [] ->
        {:ok, [res_good]}
      end)

      BlockNumber.set_max(good_block_number)

      assert {:retry, [{^address_hash_bytes, ^bad_block_number}]} =
               CoinBalanceCatchup.run(
                 [{address_hash_bytes, good_block_number}, {address_hash_bytes, bad_block_number}],
                 json_rpc_named_arguments
               )
    end
  end

  defp wait(producer) do
    producer.()
  rescue
    Ecto.NoResultsError ->
      Process.sleep(100)
      wait(producer)
  end

  defp eth_block_number_fake_response(block_quantity) do
    %{
      id: 0,
      jsonrpc: "2.0",
      result: %{
        "author" => "0x0000000000000000000000000000000000000000",
        "difficulty" => "0x20000",
        "extraData" => "0x",
        "gasLimit" => "0x663be0",
        "gasUsed" => "0x0",
        "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
        "logsBloom" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => "0x0000000000000000000000000000000000000000",
        "number" => block_quantity,
        "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
        "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "sealFields" => [
          "0x80",
          "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" =>
          "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "size" => "0x215",
        "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
        "step" => "0",
        "timestamp" => "0x0",
        "totalDifficulty" => "0x20000",
        "transactions" => [],
        "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "uncles" => []
      }
    }
  end
end
