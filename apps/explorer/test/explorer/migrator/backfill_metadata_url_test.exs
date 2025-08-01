defmodule Explorer.Migrator.BackfillMetadataURLTest do
  use Explorer.DataCase, async: false
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias Explorer.Migrator.{BackfillMetadataURL, MigrationStatus}
  alias Explorer.Chain.Token.Instance

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    :persistent_term.erase(:parsed_cidr_list)

    env = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)
    env_1 = Application.get_env(:explorer, Explorer.Migrator.BackfillMetadataURL)

    Application.put_env(
      :indexer,
      Indexer.Fetcher.TokenInstance.Helper,
      Keyword.put(env, :host_filtering_enabled?, true)
    )

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, env)
      Application.put_env(:explorer, Explorer.Migrator.BackfillMetadataURL, env_1)
    end)
  end

  describe "BackfillMetadataURL" do
    test "complete migration" do
      token = insert(:token, type: "ERC-721")

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 0
      )

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 1
      )

      token_contract_address_hash_string = to_string(token.contract_address_hash)

      encoded_url_1 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://255.255.255.255/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      encoded_url_2 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://example.com/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id_1,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000000",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             },
             %{
               id: id_2,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000001",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok,
           [%{id: id_1, jsonrpc: "2.0", result: encoded_url_1}, %{id: id_2, jsonrpc: "2.0", result: encoded_url_2}]}
        end
      )

      assert MigrationStatus.get_status("backfill_metadata_url") == nil

      BackfillMetadataURL.start_link([])
      Process.sleep(100)

      [instance_1, instance_2] =
        Instance
        |> order_by([i], asc: i.token_id)
        |> Repo.all()

      assert instance_1.skip_metadata_url == false
      assert instance_2.skip_metadata_url == false

      assert is_nil(instance_1.metadata)
      assert !is_nil(instance_2.metadata)

      assert instance_2.metadata == %{"awesome" => "metadata"}
      assert instance_2.metadata_url == "http://example.com/api/card/{id}"

      assert instance_1.error == "blacklist"

      assert MigrationStatus.get_status("backfill_metadata_url") == "completed"
    end

    test "Resolve domain" do
      token = insert(:token, type: "ERC-721")
      env = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)
      Application.put_env(:explorer, Explorer.Migrator.BackfillMetadataURL, batch_size: 1, concurrency: 1)

      Application.put_env(
        :indexer,
        Indexer.Fetcher.TokenInstance.Helper,
        Keyword.put(env, :cidr_blacklist, ["255.255.255.255/32", "1.1.1.1/32"])
      )

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 0
      )

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 1
      )

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 2
      )

      token_contract_address_hash_string = to_string(token.contract_address_hash)

      encoded_url_1 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localtest.me/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      encoded_url_2 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      encoded_url_3 =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://1.1.1.1:9393/api/card/{id}"], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000000",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: encoded_url_1}]}
        end
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000001",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: encoded_url_2}]}
        end
      )

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0xc87b56dd0000000000000000000000000000000000000000000000000000000000000002",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: encoded_url_3}]}
        end
      )

      assert MigrationStatus.get_status("backfill_metadata_url") == nil

      BackfillMetadataURL.start_link([])
      Process.sleep(500)

      [instance_1, instance_2, instance_3] =
        Instance
        |> order_by([i], asc: i.token_id)
        |> Repo.all()

      assert instance_1.skip_metadata_url == false
      assert instance_2.skip_metadata_url == false
      assert instance_3.skip_metadata_url == false

      assert is_nil(instance_1.metadata)
      assert is_nil(instance_2.metadata)
      assert is_nil(instance_3.metadata)

      assert instance_1.error == "blacklist"
      assert instance_2.error in ["nxdomain", "blacklist"]
      assert instance_3.error == "blacklist"

      assert MigrationStatus.get_status("backfill_metadata_url") == "completed"
    end

    test "drop metadata on invalid token uri response" do
      token = insert(:token, type: "ERC-1155")
      env = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)
      Application.put_env(:explorer, Explorer.Migrator.BackfillMetadataURL, batch_size: 1, concurrency: 1)

      Application.put_env(
        :indexer,
        Indexer.Fetcher.TokenInstance.Helper,
        Keyword.put(env, :cidr_blacklist, ["1.1.1.1/32"])
      )

      insert(:token_instance,
        metadata: %{awesome: "metadata"},
        token_contract_address_hash: token.contract_address_hash,
        token_id: 0
      )

      token_contract_address_hash_string = to_string(token.contract_address_hash)

      encoded_url_1 =
        "0x" <>
          (ABI.TypeEncoder.encode([""], %ABI.FunctionSelector{
             function: nil,
             types: [
               :string
             ]
           })
           |> Base.encode16(case: :lower))

      expect(
        EthereumJSONRPC.Mox,
        :json_rpc,
        fn [
             %{
               id: id,
               jsonrpc: "2.0",
               method: "eth_call",
               params: [
                 %{
                   data: "0x0e89341c0000000000000000000000000000000000000000000000000000000000000000",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id, jsonrpc: "2.0", result: encoded_url_1}]}
        end
      )

      assert MigrationStatus.get_status("backfill_metadata_url") == nil

      BackfillMetadataURL.start_link([])
      Process.sleep(500)

      [instance_1] =
        Instance
        |> order_by([i], asc: i.token_id)
        |> Repo.all()

      assert instance_1.skip_metadata_url == false

      assert is_nil(instance_1.metadata)

      assert instance_1.error == "no uri"

      assert MigrationStatus.get_status("backfill_metadata_url") == "completed"
    end
  end
end
