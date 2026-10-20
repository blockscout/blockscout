# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.V2.BlockChannelTest do
  use BlockScoutWeb.ChannelCase

  import Explorer.QuerySources, only: [with_query_sources: 1]

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.{Address, Block}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.MicroserviceInterfaces.{BENS, Metadata}
  alias Explorer.Repo
  alias Plug.Conn

  @chain_id 1

  setup do
    old_notifier = Application.get_env(:block_scout_web, Notifier, [])
    topic = "blocks:new_block"
    @endpoint.subscribe(topic)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:block_scout_web, Notifier, old_notifier)
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
      Phoenix.PubSub.unsubscribe(BlockScoutWeb.PubSub, topic)
    end)

    {:ok, topic: topic}
  end

  test "subscribed user is notified of new_block event", %{topic: topic} do
    block = insert(:block, number: 1)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}} ->
        assert true
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end

  test "user is able to join to common channels", %{topic: topic} do
    common_channels = ["new_block", "indexing", "indexing_internal_transactions"]

    Enum.each(common_channels, fn channel ->
      assert {:ok, _reply, _socket} =
               BlockScoutWeb.V2.UserSocket
               |> socket("no_id", %{})
               |> subscribe_and_join("blocks:#{channel}")
    end)
  end

  test "new_block payload includes miner ENS and metadata when microservices are enabled", %{topic: topic} do
    bypass = Bypass.open()
    on_exit(fn -> Bypass.down(bypass) end)
    enable_enrichment_microservices("http://localhost:#{bypass.port}")
    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_timeout: :timer.seconds(5))

    miner = insert(:address)

    Bypass.expect_once(bypass, "POST", "/api/v1/#{@chain_id}/addresses:batch_resolve_names", fn conn ->
      Conn.resp(
        conn,
        200,
        Utils.JSON.encode!(%{
          "names" => %{
            Address.checksum(miner.hash) => "miner.eth"
          }
        })
      )
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/metadata", fn conn ->
      Conn.resp(
        conn,
        200,
        Utils.JSON.encode!(%{
          "addresses" => %{
            Address.checksum(miner.hash) => %{
              "tags" => []
            }
          }
        })
      )
    end)

    block = insert(:block, number: 1, miner: miner)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: block_payload}} ->
        assert block_payload["miner"]["ens_domain_name"] == "miner.eth"
        assert block_payload["miner"]["metadata"] == %{"tags" => []}
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end

  test "new_block payloads of a batch are enriched with a single request per microservice", %{topic: topic} do
    bypass = Bypass.open()
    on_exit(fn -> Bypass.down(bypass) end)
    enable_enrichment_microservices("http://localhost:#{bypass.port}")
    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_timeout: :timer.seconds(5))

    first_miner = insert(:address)
    second_miner = insert(:address)

    # A second request to either microservice fails the test
    Bypass.expect_once(bypass, "POST", "/api/v1/#{@chain_id}/addresses:batch_resolve_names", fn conn ->
      Conn.resp(
        conn,
        200,
        Jason.encode!(%{
          "names" => %{
            Address.checksum(first_miner.hash) => "first.eth",
            Address.checksum(second_miner.hash) => "second.eth"
          }
        })
      )
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/metadata", fn conn ->
      Conn.resp(
        conn,
        200,
        Jason.encode!(%{
          "addresses" => %{
            Address.checksum(first_miner.hash) => %{"tags" => []},
            Address.checksum(second_miner.hash) => %{"tags" => []}
          }
        })
      )
    end)

    first_block = insert(:block, number: 1, miner: first_miner)
    second_block = insert(:block, number: 2, miner: second_miner)
    third_block = insert(:block, number: 3, miner: first_miner)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [second_block, third_block, first_block]})

    miners_info =
      for _ <- 1..3 do
        assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: block_payload}},
                       :timer.seconds(5)

        {block_payload["height"], block_payload["miner"]["ens_domain_name"], block_payload["miner"]["metadata"]}
      end

    assert Enum.sort(miners_info) == [
             {1, "first.eth", %{"tags" => []}},
             {2, "second.eth", %{"tags" => []}},
             {3, "first.eth", %{"tags" => []}}
           ]
  end

  test "new_block payload skips miner ENS when DISABLE_BLOCKS_BENS_PRELOAD is set", %{topic: topic} do
    bypass = Bypass.open()
    on_exit(fn -> Bypass.down(bypass) end)
    enable_enrichment_microservices("http://localhost:#{bypass.port}", disable_blocks_bens_preload: true)
    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_timeout: :timer.seconds(5))

    miner = insert(:address)

    # Would put the name into the payload, were BENS asked
    Bypass.stub(bypass, "POST", "/api/v1/#{@chain_id}/addresses:batch_resolve_names", fn conn ->
      Conn.resp(conn, 200, Jason.encode!(%{"names" => %{Address.checksum(miner.hash) => "miner.eth"}}))
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/metadata", fn conn ->
      Conn.resp(conn, 200, Jason.encode!(%{"addresses" => %{Address.checksum(miner.hash) => %{"tags" => []}}}))
    end)

    block = insert(:block, number: 1, miner: miner)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: block_payload}},
                   :timer.seconds(5)

    assert is_nil(block_payload["miner"]["ens_domain_name"])
    assert block_payload["miner"]["metadata"] == %{"tags" => []}
  end

  test "new_block broadcast of a batch makes as many queries as of a single block", %{topic: topic} do
    [block | batch] =
      for number <- 1..4 do
        block = insert(:block, number: number)
        :transaction |> insert() |> with_block(block)
        insert(:reward, address_hash: block.miner_hash, block_hash: block.hash)

        # The blocks of a chain event come without loaded associations
        Repo.get!(Block, block.hash)
      end

    {_, block_query_sources} =
      with_query_sources(fn -> Notifier.handle_event({:chain_event, :blocks, :realtime, [block]}) end)

    {_, batch_query_sources} =
      with_query_sources(fn -> Notifier.handle_event({:chain_event, :blocks, :realtime, batch}) end)

    for number <- 1..4 do
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "new_block",
                       payload: %{block: %{"height" => ^number, "transactions_count" => 1, "rewards" => [_]}}
                     },
                     :timer.seconds(5)
    end

    assert "transactions" in block_query_sources
    assert "block_rewards" in block_query_sources
    assert Enum.frequencies(batch_query_sources) == Enum.frequencies(block_query_sources)
  end

  test "new_block broadcast sends the consecutive blocks of a batch without waiting", %{topic: topic} do
    blocks = for number <- 11..13, do: insert(:block, number: number)

    :ets.insert(:last_broadcasted_block, {:number, 10})
    on_exit(fn -> :ets.delete(:last_broadcasted_block, :number) end)

    Notifier.handle_event({:chain_event, :blocks, :realtime, Enum.reverse(blocks)})

    # A block waiting for its predecessor would be broadcast from a task later on
    for number <- 11..13 do
      assert_received %Phoenix.Socket.Broadcast{
        topic: ^topic,
        event: "new_block",
        payload: %{block: %{"height" => ^number}}
      }
    end
  end

  test "new_block broadcast skips enrichment when DISABLE_BLOCK_BROADCAST_ENRICHMENT is set", %{topic: topic} do
    bypass = Bypass.open()
    on_exit(fn -> Bypass.down(bypass) end)
    enable_enrichment_microservices("http://localhost:#{bypass.port}")
    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_disabled: true)

    # No Bypass.expect calls — any HTTP call to the microservices would cause Bypass to raise
    Bypass.pass(bypass)

    miner = insert(:address)
    block = insert(:block, number: 1, miner: miner)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    receive do
      %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: block_payload}} ->
        assert is_nil(block_payload["miner"]["ens_domain_name"])
    after
      :timer.seconds(5) ->
        assert false, "Expected message received nothing."
    end
  end

  test "new_block broadcast falls back quickly when enrichment services are unavailable", %{topic: topic} do
    enable_enrichment_microservices("http://127.0.0.1:9")
    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_timeout: 50)

    miner = insert(:address)

    block = insert(:block, number: 1, miner: miner)

    timeout =
      Application.get_env(:block_scout_web, Notifier, [])
      |> Keyword.get(:block_broadcast_enrichment_timeout, 200)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}}, timeout + 200
  end

  defp enable_enrichment_microservices(service_url, bens_options \\ []) do
    old_chain_id = Application.get_env(:block_scout_web, :chain_id)
    old_bens = Application.get_env(:explorer, BENS)
    old_metadata = Application.get_env(:explorer, Metadata)

    Application.put_env(:block_scout_web, :chain_id, @chain_id)

    Application.put_env(
      :explorer,
      BENS,
      Keyword.merge(old_bens || [], [service_url: service_url, enabled: true, protocols: []] ++ bens_options)
    )

    Application.put_env(:explorer, Metadata, Keyword.merge(old_metadata || [], service_url: service_url, enabled: true))

    on_exit(fn ->
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, BENS, old_bens)
      Application.put_env(:explorer, Metadata, old_metadata)
    end)
  end
end
