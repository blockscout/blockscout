# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.V2.BlockChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.{Address, Block}
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Repo
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

  test "new_block payloads of a batch are enriched with a single request per microservice", %{topic: topic} do
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

    first_miner = insert(:address)
    second_miner = insert(:address)

    # A second request to either microservice fails the test
    Bypass.expect_once(bypass, "POST", "/api/v1/#{chain_id}/addresses:batch_resolve_names", fn conn ->
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

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

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

  test "new_block broadcast preloads the data of a batch with a single query per association", %{topic: topic} do
    blocks =
      for number <- 1..3 do
        block = insert(:block, number: number)
        :transaction |> insert() |> with_block(block)
        insert(:reward, address_hash: block.miner_hash, block_hash: block.hash)

        # The blocks of a chain event come without loaded associations
        Repo.get!(Block, block.hash)
      end

    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)

    handler_id = {__MODULE__, make_ref()}
    :ok = :telemetry.attach(handler_id, [:explorer, :repo, :query], &__MODULE__.handle_query_event/4, self())
    on_exit(fn -> :telemetry.detach(handler_id) end)

    Notifier.handle_event({:chain_event, :blocks, :realtime, blocks})

    for number <- 1..3 do
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "new_block",
                       payload: %{block: %{"height" => ^number, "transactions_count" => 1, "rewards" => [_]}}
                     },
                     :timer.seconds(5)
    end

    query_counts =
      collect_query_sources([])
      |> Enum.frequencies()
      |> Map.take(["addresses", "transactions", "block_rewards"])

    assert query_counts == %{"addresses" => 1, "transactions" => 1, "block_rewards" => 1}
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

  defp collect_query_sources(acc) do
    receive do
      {:query_source, source} -> collect_query_sources([source | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  # Ecto runs the preloads of the same level in parallel tasks, hence the queries
  # issued on behalf of the test process are told apart by the `$callers`.
  @doc false
  def handle_query_event(_event, _measurements, %{source: source}, test_pid) do
    if test_pid in [self() | Process.get(:"$callers", [])], do: send(test_pid, {:query_source, source})
  end
end
