defmodule BlockScoutWeb.V2.BlockChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.Address
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Plug.Conn

  setup do
    old_notifier = Application.get_env(:block_scout_web, Notifier, [])
    topic = "blocks:new_block"
    @endpoint.subscribe(topic)

    on_exit(fn ->
      Application.put_env(:block_scout_web, Notifier, old_notifier)
      Phoenix.PubSub.unsubscribe(BlockScoutWeb.PubSub, topic)
    end)

    {:ok, topic: topic}
  end

  test "subscribed user is notified of new_block event", %{topic: topic} do
    block = insert(:block, number: 1)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

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

    old_chain_id = Application.get_env(:block_scout_web, :chain_id)
    old_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
    old_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)
    old_tesla_adapter = Application.get_env(:tesla, :adapter)

    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    chain_id = 1
    Application.put_env(:block_scout_web, :chain_id, chain_id)

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
      service_url: "http://localhost:#{bypass.port}",
      enabled: true,
      protocols: []
    )

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
      service_url: "http://localhost:#{bypass.port}",
      enabled: true
    )

    on_exit(fn ->
      Bypass.down(bypass)
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_bens)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_metadata)
      Application.put_env(:tesla, :adapter, old_tesla_adapter)
    end)

    miner = insert(:address)

    Bypass.expect_once(bypass, "POST", "/api/v1/#{chain_id}/addresses:batch_resolve_names", fn conn ->
      Conn.resp(
        conn,
        200,
        Jason.encode!(%{
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
        Jason.encode!(%{
          "addresses" => %{
            Address.checksum(miner.hash) => %{
              "tags" => []
            }
          }
        })
      )
    end)

    block = insert(:block, number: 1, miner: miner)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

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

  test "new_block broadcast skips enrichment when DISABLE_BLOCK_BROADCAST_ENRICHMENT is set", %{topic: topic} do
    bypass = Bypass.open()

    old_chain_id = Application.get_env(:block_scout_web, :chain_id)
    old_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
    old_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)

    Application.put_env(:block_scout_web, :chain_id, 1)

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
      service_url: "http://localhost:#{bypass.port}",
      enabled: true,
      protocols: []
    )

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
      service_url: "http://localhost:#{bypass.port}",
      enabled: true
    )

    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_disabled: true)

    on_exit(fn ->
      Bypass.down(bypass)
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_bens)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_metadata)
    end)

    # No Bypass.expect calls — any HTTP call to the microservices would cause Bypass to raise
    Bypass.pass(bypass)

    miner = insert(:address)
    block = insert(:block, number: 1, miner: miner)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

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
    old_chain_id = Application.get_env(:block_scout_web, :chain_id)
    old_bens = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.BENS)
    old_metadata = Application.get_env(:explorer, Explorer.MicroserviceInterfaces.Metadata)
    old_tesla_adapter = Application.get_env(:tesla, :adapter)
    Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

    chain_id = 1
    Application.put_env(:block_scout_web, :chain_id, chain_id)

    Application.put_env(:block_scout_web, Notifier, block_broadcast_enrichment_timeout: 50)

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS,
      service_url: "http://127.0.0.1:9",
      enabled: true,
      protocols: []
    )

    Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata,
      service_url: "http://127.0.0.1:9",
      enabled: true
    )

    on_exit(fn ->
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.BENS, old_bens)
      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.Metadata, old_metadata)
      Application.put_env(:tesla, :adapter, old_tesla_adapter)
    end)

    miner = insert(:address)

    block = insert(:block, number: 1, miner: miner)

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    timeout =
      Application.get_env(:block_scout_web, Notifier, [])
      |> Keyword.get(:block_broadcast_enrichment_timeout, 200)

    Notifier.handle_event({:chain_event, :blocks, :realtime, [block]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "new_block", payload: %{block: _}}, timeout + 200
  end
end
