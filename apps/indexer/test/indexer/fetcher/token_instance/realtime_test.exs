defmodule Indexer.Fetcher.TokenInstance.RealtimeTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Repo
  alias Explorer.Chain.Token.Instance
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.TokenInstance.Realtime, as: TokenInstanceRealtime
  alias Plug.Conn

  setup :verify_on_exit!
  setup :set_mox_global

  describe "Check how works retry in realtime" do
    setup do
      config = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime)
      new_config = config |> Keyword.put(:retry_with_cooldown?, true) |> Keyword.put(:retry_timeout, 100)

      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime, new_config)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Realtime, config)
      end)

      :ok
    end

    test "retry once after timeout" do
      bypass = Bypass.open()

      []
      |> TokenInstanceRealtime.Supervisor.child_spec()
      |> ExUnit.Callbacks.start_supervised!()

      json = """
      {
        "name": "name"
      }
      """

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [
                                %{
                                  id: 0,
                                  jsonrpc: "2.0",
                                  method: "eth_call",
                                  params: [
                                    %{
                                      data:
                                        "0x0e89341c0000000000000000000000000000000000000000000000000000000000000309",
                                      to: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
                                    },
                                    "latest"
                                  ]
                                }
                              ],
                              _options ->
        {:ok,
         [
           %{
             id: 0,
             jsonrpc: "2.0",
             result: encoded_url
           }
         ]}
      end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000309",
        fn conn ->
          Conn.resp(conn, 404, "Not found")
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000309",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      token =
        insert(:token,
          contract_address: build(:address, hash: "0x5caebd3b32e210e85ce3e9d51638b9c445481567"),
          type: "ERC-1155"
        )

      insert(:token_instance,
        token_id: 777,
        token_contract_address_hash: token.contract_address_hash,
        metadata: nil,
        error: nil
      )

      TokenInstanceRealtime.async_fetch([
        %{token_contract_address_hash: token.contract_address_hash, token_ids: [Decimal.new(777)]}
      ])

      wait_for_tasks(TokenInstanceRealtime)

      [instance] = Repo.all(Instance)

      assert is_nil(instance.error)
      assert instance.metadata == %{"name" => "name"}
      Bypass.down(bypass)
    end
  end

  defp wait_for_tasks(buffered_task) do
    wait_until(:timer.seconds(10000), fn ->
      counts = BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end

  defp wait_until(timeout, producer) do
    parent = self()
    ref = make_ref()

    spawn(fn -> do_wait_until(parent, ref, producer) end)

    receive do
      {^ref, :ok} -> :ok
    after
      timeout -> exit(:timeout)
    end
  end

  defp do_wait_until(parent, ref, producer) do
    if producer.() do
      send(parent, {ref, :ok})
    else
      :timer.sleep(100)
      do_wait_until(parent, ref, producer)
    end
  end
end
