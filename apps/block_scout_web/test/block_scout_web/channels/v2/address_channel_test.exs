# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.V2.AddressChannelTest do
  use BlockScoutWeb.ChannelCase,
    # cache is shared in `Explorer.Chain.Cache.Counters.AddressesAggregates`
    async: false

  alias BlockScoutWeb.Notifier
  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Chain.Cache.Counters.AddressesAggregates
  alias Explorer.MicroserviceInterfaces.{BENS, Metadata}
  alias Plug.Conn

  test "subscribed user is notified of new_address count event" do
    topic = "addresses:new_address"
    @endpoint.subscribe(topic)

    address = insert(:address)

    AddressesAggregates.consolidate()

    Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "count", payload: %{count: _}}, :timer.seconds(5)
  end

  describe "user subscribed to address" do
    setup do
      address = insert(:address)
      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)
      {:ok, %{address: address, topic: topic}}
    end

    test "notified of balance_update for matching address", %{address: address, topic: topic} do
      {:ok, balance} = Wei.cast(1)
      address_with_balance = %{address | fetched_coin_balance: balance}

      AddressesAggregates.consolidate()

      Notifier.handle_event({:chain_event, :addresses, :realtime, [address_with_balance]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "balance", payload: payload},
                     :timer.seconds(5)

      assert payload.balance == balance.value
    end

    test "not notified of balance_update if fetched_coin_balance is nil", %{address: address} do
      AddressesAggregates.consolidate()

      Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

      refute_receive _, 100, "Message was broadcast for nil fetched_coin_balance."
    end

    test "notified of new_pending_transaction for matching from_address", %{address: address, topic: topic} do
      pending = insert(:transaction, from_address: address)

      Notifier.handle_event({:chain_event, :transactions, :realtime, [pending]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "pending_transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == pending.hash
    end

    test "notified of new_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash
    end

    test "notified of new_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash
    end

    test "not notified twice of new_transaction if to and from address are equal", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "transaction",
                       payload: %{transactions: _} = payload
                     },
                     :timer.seconds(5)

      assert List.first(payload.transactions)["hash"] == transaction.hash

      refute_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: %{transactions: _}},
                     100,
                     "Received duplicate broadcast."
    end
  end

  describe "participants enrichment" do
    setup do
      old_notifier = Application.get_env(:block_scout_web, Notifier, [])
      on_exit(fn -> Application.put_env(:block_scout_web, Notifier, old_notifier) end)

      Application.put_env(
        :block_scout_web,
        Notifier,
        Keyword.merge(old_notifier, transaction_broadcast_enrichment_timeout: :timer.seconds(5))
      )

      bypass = Bypass.open()
      on_exit(fn -> Bypass.down(bypass) end)
      enable_enrichment_microservices("http://localhost:#{bypass.port}")

      address = insert(:address)
      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)

      {:ok, %{address: address, topic: topic, bypass: bypass}}
    end

    test "transaction payload names its participants the way the REST list does", %{
      address: address,
      topic: topic,
      bypass: bypass
    } do
      expect_enrichment(bypass, address)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload},
                     :timer.seconds(5)

      [transaction_payload] = payload.transactions
      assert transaction_payload["to"]["ens_domain_name"] == "token.eth"
      assert transaction_payload["to"]["metadata"] == %{"tags" => [name_tag()]}
    end

    test "token transfer payload names its participants the way the REST list does", %{
      address: address,
      topic: topic,
      bypass: bypass
    } do
      expect_enrichment(bypass, address)

      token = insert(:token, type: "ERC-20")

      transaction =
        :transaction
        |> insert(to_address: token.contract_address)
        |> with_block()

      token_transfer =
        insert(:token_transfer,
          to_address: address,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block: transaction.block,
          block_number: transaction.block_number,
          log_index: 0,
          token_type: "ERC-20",
          block_consensus: true
        )

      Notifier.handle_event({:chain_event, :token_transfers, :realtime, [token_transfer]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "token_transfer", payload: payload},
                     :timer.seconds(5)

      [token_transfer_payload] = payload.token_transfers
      assert token_transfer_payload["to"]["ens_domain_name"] == "token.eth"
      assert token_transfer_payload["to"]["metadata"] == %{"tags" => [name_tag()]}
    end

    test "transaction payload skips enrichment when DISABLE_TRANSACTION_BROADCAST_ENRICHMENT is set", %{
      address: address,
      topic: topic,
      bypass: bypass
    } do
      Application.put_env(:block_scout_web, Notifier, transaction_broadcast_enrichment_disabled: true)

      # No Bypass.expect calls: any request to the microservices fails the test
      Bypass.pass(bypass)

      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload},
                     :timer.seconds(5)

      [transaction_payload] = payload.transactions
      assert is_nil(transaction_payload["to"]["ens_domain_name"])
      assert is_nil(transaction_payload["to"]["metadata"])
    end
  end

  @chain_id 1

  defp name_tag do
    %{
      "slug" => "usdc-token",
      "name" => "USDC Token",
      "tagType" => "name",
      "ordinal" => 0,
      "meta" => %{}
    }
  end

  defp expect_enrichment(bypass, address) do
    checksum = Address.checksum(address.hash)

    Bypass.expect_once(bypass, "POST", "/api/v1/#{@chain_id}/addresses:batch_resolve_names", fn conn ->
      Conn.resp(conn, 200, Utils.JSON.encode!(%{"names" => %{checksum => "token.eth"}}))
    end)

    Bypass.expect_once(bypass, "GET", "/api/v1/metadata", fn conn ->
      tag = Map.put(name_tag(), "meta", "{}")
      Conn.resp(conn, 200, Utils.JSON.encode!(%{"addresses" => %{checksum => %{"tags" => [tag]}}}))
    end)
  end

  defp enable_enrichment_microservices(service_url) do
    old_chain_id = Application.get_env(:block_scout_web, :chain_id)
    old_bens = Application.get_env(:explorer, BENS)
    old_metadata = Application.get_env(:explorer, Metadata)

    Application.put_env(:block_scout_web, :chain_id, @chain_id)

    Application.put_env(
      :explorer,
      BENS,
      Keyword.merge(old_bens || [], service_url: service_url, enabled: true, protocols: [])
    )

    Application.put_env(:explorer, Metadata, Keyword.merge(old_metadata || [], service_url: service_url, enabled: true))

    on_exit(fn ->
      Application.put_env(:block_scout_web, :chain_id, old_chain_id)
      Application.put_env(:explorer, BENS, old_bens)
      Application.put_env(:explorer, Metadata, old_metadata)
    end)
  end
end
