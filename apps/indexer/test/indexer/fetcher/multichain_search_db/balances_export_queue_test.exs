defmodule Indexer.Fetcher.MultichainSearchDbExport.BalancesExportQueueTest do
  use ExUnit.Case
  use Explorer.DataCase

  import ExUnit.CaptureLog, only: [capture_log: 1]
  import Mox

  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Chain.MultichainSearchDb.BalancesExportQueue
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.TestHelper

  alias Indexer.Fetcher.MultichainSearchDbExport.BalancesExportQueue,
    as: MultichainSearchDbExportBalancesExportQueue

  alias Plug.Conn

  @moduletag :capture_log

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})
    Application.put_env(:indexer, MultichainSearchDbExportBalancesExportQueue.Supervisor, disabled?: false)

    on_exit(fn ->
      Application.put_env(:indexer, MultichainSearchDbExportBalancesExportQueue.Supervisor, disabled?: true)
    end)

    :ok
  end

  describe "init/3" do
    setup do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
      end)
    end

    test "initializes with data from the retry queue" do
      address_hash_bytes = "66A9B160F6a06f53f23785F069882Ee7337180E8" |> Base.decode16!(case: :mixed)
      erc_20_contract_address_hash_bytes = "A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" |> Base.decode16!(case: :mixed)
      nft_contract_address_hash_bytes = "B01b6a7EF8560017AA59A990e39f26b8df29F80f" |> Base.decode16!(case: :mixed)

      insert(:multichain_search_db_export_balances_queue, %{
        address_hash: address_hash_bytes,
        token_contract_address_hash_or_native: "native",
        value: 100,
        token_id: nil
      })

      insert(:multichain_search_db_export_balances_queue, %{
        address_hash: address_hash_bytes,
        token_contract_address_hash_or_native: erc_20_contract_address_hash_bytes,
        value: 200,
        token_id: nil
      })

      insert(:multichain_search_db_export_balances_queue, %{
        address_hash: address_hash_bytes,
        token_contract_address_hash_or_native: nft_contract_address_hash_bytes,
        value: nil,
        token_id: 12345
      })

      reducer = fn data, acc -> [data | acc] end

      pid =
        []
        |> MultichainSearchDbExportBalancesExportQueue.Supervisor.child_spec()
        |> ExUnit.Callbacks.start_supervised!()

      results = MultichainSearchDbExportBalancesExportQueue.init([], reducer, nil)

      assert Enum.count(results) == 3

      assert Enum.member?(results, %{
               address_hash: address_hash_bytes,
               token_contract_address_hash_or_native: "native",
               value: %Wei{value: Decimal.new(100)},
               token_id: nil
             })

      assert Enum.member?(results, %{
               address_hash: address_hash_bytes,
               token_contract_address_hash_or_native: erc_20_contract_address_hash_bytes,
               value: %Wei{value: Decimal.new(200)},
               token_id: nil
             })

      assert Enum.member?(results, %{
               address_hash: address_hash_bytes,
               token_contract_address_hash_or_native: nft_contract_address_hash_bytes,
               value: nil,
               token_id: Decimal.new(12345)
             })

      :timer.sleep(10)
      GenServer.stop(pid)
    end
  end

  describe "run/2" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:#{bypass.port}",
        api_key: "12345",
        addresses_chunk_size: 7000
      )

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Bypass.down(bypass)
      end)

      {:ok, bypass: bypass}
    end

    test "successfully processes multichain search db export retry queue data", %{bypass: bypass} do
      address_hash_bytes = "66A9B160F6a06f53f23785F069882Ee7337180E8" |> Base.decode16!(case: :mixed)
      erc_20_contract_address_hash_bytes = "A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" |> Base.decode16!(case: :mixed)
      nft_contract_address_hash_bytes = "B01b6a7EF8560017AA59A990e39f26b8df29F80f" |> Base.decode16!(case: :mixed)

      export_data = [
        %{
          address_hash: address_hash_bytes,
          token_contract_address_hash_or_native: "native",
          value: %Wei{value: Decimal.new(100)}
        },
        %{
          address_hash: erc_20_contract_address_hash_bytes,
          token_contract_address_hash_or_native: erc_20_contract_address_hash_bytes,
          value: %Wei{value: Decimal.new(200)},
          token_id: nil
        },
        %{
          address_hash: nft_contract_address_hash_bytes,
          token_contract_address_hash_or_native: nft_contract_address_hash_bytes,
          value: nil,
          token_id: Decimal.new(12345)
        }
      ]

      TestHelper.get_chain_id_mock()

      Bypass.expect_once(bypass, "POST", "/api/v1/import:batch", fn conn ->
        Conn.resp(
          conn,
          200,
          Jason.encode!(%{"status" => "ok"})
        )
      end)

      assert :ok = MultichainSearchDbExportBalancesExportQueue.run(export_data, nil)
    end

    test "returns {:retry, failed_data} on error where failed_data is only chunks that failed to export", %{
      bypass: _bypass
    } do
      Application.put_env(:explorer, MultichainSearch,
        service_url: "http://localhost:1234",
        api_key: "12345",
        addresses_chunk_size: 1
      )

      Application.put_env(:explorer, :http_adapter, Explorer.Mox.HTTPoison)

      on_exit(fn ->
        Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
        Application.put_env(:explorer, :http_adapter, HTTPoison)
      end)

      address_1 = insert(:address)
      address_2 = insert(:address)
      address_2_hash_string = to_string(address_2) |> String.downcase()
      address_3 = insert(:address)
      address_3_hash_string = to_string(address_3) |> String.downcase()
      address_4 = insert(:address)
      address_4_hash_string = to_string(address_4) |> String.downcase()
      address_4_hash_string_checksummed = Address.checksum(address_4)
      address_5 = insert(:address)
      address_5_hash_string = to_string(address_5) |> String.downcase()
      token_address_1 = insert(:address)
      token_address_1_hash_string = to_string(token_address_1) |> String.downcase()
      token_address_2 = insert(:address)
      token_address_2_hash_string = to_string(token_address_2) |> String.downcase()

      export_data = [
        %{
          address_hash: address_1.hash.bytes,
          token_contract_address_hash_or_native: "native",
          value: %Wei{value: Decimal.new(100)}
        },
        %{
          address_hash: address_2.hash.bytes,
          token_contract_address_hash_or_native: token_address_1.hash.bytes,
          value: %Wei{value: Decimal.new(200)},
          token_id: nil
        },
        %{
          address_hash: address_3.hash.bytes,
          token_contract_address_hash_or_native: token_address_2.hash.bytes,
          value: %Wei{value: Decimal.new(300)},
          token_id: nil
        },
        %{
          address_hash: address_4.hash.bytes,
          token_contract_address_hash_or_native: "native",
          value: %Wei{value: Decimal.new(400)}
        },
        %{
          address_hash: address_5.hash.bytes,
          token_contract_address_hash_or_native: token_address_1.hash.bytes,
          value: %Wei{value: Decimal.new(500)},
          token_id: nil
        }
      ]

      TestHelper.get_chain_id_mock()

      for _ <- 0..1 do
        Explorer.Mox.HTTPoison
        |> expect(:post, fn "http://localhost:1234/api/v1/import:batch",
                            body,
                            [{"Content-Type", "application/json"}],
                            _options ->
          case Jason.decode(body) do
            {:ok, %{"address_coin_balances" => [%{"address_hash" => ^address_4_hash_string_checksummed}]}} ->
              {:ok, %HTTPoison.Response{status_code: 500, body: Jason.encode!(%{"code" => 0, "message" => "Error"})}}

            _ ->
              {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"status" => "ok"})}}
          end
        end)
      end

      val1 = Decimal.new(200) |> Wei.cast() |> elem(1)
      val2 = Decimal.new(300) |> Wei.cast() |> elem(1)
      val3 = Decimal.new(400) |> Wei.cast() |> elem(1)
      val4 = Decimal.new(500) |> Wei.cast() |> elem(1)

      log =
        capture_log(fn ->
          assert {:retry,
                  %{
                    address_coin_balances: [
                      %{
                        address_hash: ^address_4_hash_string,
                        token_contract_address_hash_or_native: "native",
                        value: ^val3
                      }
                    ],
                    address_token_balances: [
                      %{
                        address_hash: ^address_5_hash_string,
                        token_address_hash: ^token_address_1_hash_string,
                        value: ^val4,
                        token_id: nil
                      },
                      %{
                        address_hash: ^address_3_hash_string,
                        token_address_hash: ^token_address_2_hash_string,
                        value: ^val2,
                        token_id: nil
                      },
                      %{
                        address_hash: ^address_2_hash_string,
                        token_address_hash: ^token_address_1_hash_string,
                        value: ^val1,
                        token_id: nil
                      }
                    ]
                  }} = MultichainSearchDbExportBalancesExportQueue.run(export_data, nil)
        end)

      assert Repo.aggregate(BalancesExportQueue, :count, :id) == 4
      assert log =~ "Batch export retry to the Multichain Search DB failed"

      export_data_2 = [
        %{
          address_hash: address_2.hash.bytes,
          token_contract_address_hash_or_native: token_address_1.hash.bytes,
          value: %Wei{value: Decimal.new(200)},
          token_id: nil
        },
        %{
          address_hash: address_3.hash.bytes,
          token_contract_address_hash_or_native: token_address_2.hash.bytes,
          value: %Wei{value: Decimal.new(300)},
          token_id: nil
        },
        %{
          address_hash: address_4.hash.bytes,
          token_contract_address_hash_or_native: "native",
          value: %Wei{value: Decimal.new(400)}
        },
        %{
          address_hash: address_5.hash.bytes,
          token_contract_address_hash_or_native: token_address_1.hash.bytes,
          value: %Wei{value: Decimal.new(500)},
          token_id: nil
        }
      ]

      Explorer.Mox.HTTPoison
      |> expect(:post, fn "http://localhost:1234/api/v1/import:batch",
                          body,
                          [{"Content-Type", "application/json"}],
                          _options ->
        case Jason.decode(body) do
          _ ->
            {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(%{"status" => "ok"})}}
        end
      end)

      MultichainSearchDbExportBalancesExportQueue.run(export_data_2, nil)

      assert Repo.aggregate(BalancesExportQueue, :count, :id) == 0

      Application.put_env(:explorer, MultichainSearch, service_url: nil, api_key: nil, addresses_chunk_size: 7000)
    end
  end
end
