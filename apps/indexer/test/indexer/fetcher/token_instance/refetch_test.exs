defmodule Indexer.Fetcher.TokenInstance.RefetchTest do
  use Explorer.DataCase
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias Explorer.Chain.Token.Instance
  alias Indexer.Fetcher.TokenInstance.Refetch
  alias Indexer.Fetcher.OnDemand.NFTCollectionMetadataRefetch, as: NFTCollectionMetadataRefetchOnDemand
  alias Plug.Conn

  describe "child_spec/1" do
    test "merges default options with provided options" do
      init_options = [max_batch_size: 5]
      gen_server_options = [name: :test_server]

      child_spec = Refetch.child_spec([init_options, gen_server_options])

      assert %{
               id: Refetch,
               start: {Indexer.BufferedTask, :start_link, _}
             } = child_spec
    end
  end

  describe "init/3" do
    test "initializes with token instances marked to refetch" do
      initial_acc = []
      reducer = fn data, acc -> [data | acc] end

      token = insert(:token, name: "FN2 Token", type: "ERC-1155")

      token_instance_1 =
        insert(:token_instance,
          token_id: 1,
          token_contract_address_hash: token.contract_address_hash,
          metadata: nil,
          error: ":marked_to_refetch"
        )

      token_instance_2 =
        insert(:token_instance,
          token_id: 2,
          token_contract_address_hash: token.contract_address_hash,
          metadata: nil,
          error: ":marked_to_refetch"
        )

      response =
        [token_instance_2, token_instance_1]
        |> Enum.map(fn %Instance{token_id: token_id, token_contract_address_hash: token_contract_address_hash} ->
          %{
            token_id: token_id,
            contract_address_hash: token_contract_address_hash
          }
        end)

      assert Refetch.init(initial_acc, reducer, []) == response
    end
  end

  describe "run/2" do
    setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
      mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

      start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

      start_supervised!(
        {NFTCollectionMetadataRefetchOnDemand,
         [mocked_json_rpc_named_arguments, [name: NFTCollectionMetadataRefetchOnDemand]]}
      )

      :ok
    end

    test "filters and fetches token instances marked to refetch" do
      bypass = Bypass.open()

      Application.put_env(:tesla, :adapter, Tesla.Adapter.Mint)

      json = """
      {
        "name": "nice nft"
      }
      """

      token = insert(:token, name: "FN2 Token", type: "ERC-1155")

      token_instance_1 =
        insert(:token_instance,
          token_id: 1,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{uri: "http://example.com"},
          error: nil
        )

      token_instance_2 =
        insert(:token_instance,
          token_id: 2,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{uri: "http://example.com"},
          error: nil
        )

      token_instances =
        [token_instance_2, token_instance_1]
        |> Enum.map(fn %Instance{token_id: token_id, token_contract_address_hash: token_contract_address_hash} ->
          %{
            token_id: token_id,
            contract_address_hash: token_contract_address_hash
          }
        end)

      token_contract_address_hash_string = to_string(token.contract_address_hash)

      encoded_url =
        "0x" <>
          (ABI.TypeEncoder.encode(["http://localhost:#{bypass.port}/api/card/{id}"], %ABI.FunctionSelector{
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
                   data: "0x0e89341c0000000000000000000000000000000000000000000000000000000000000002",
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
                   data: "0x0e89341c0000000000000000000000000000000000000000000000000000000000000001",
                   to: ^token_contract_address_hash_string
                 },
                 "latest"
               ]
             }
           ],
           _options ->
          {:ok, [%{id: id_1, jsonrpc: "2.0", result: encoded_url}, %{id: id_2, jsonrpc: "2.0", result: encoded_url}]}
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000001",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/card/0000000000000000000000000000000000000000000000000000000000000002",
        fn conn ->
          Conn.resp(conn, 200, json)
        end
      )

      NFTCollectionMetadataRefetchOnDemand.trigger_refetch(token)

      :timer.sleep(150)

      marked_token_instances =
        Repo.all(
          from(i in Instance,
            where: i.token_contract_address_hash == ^token.contract_address_hash
          )
        )

      for marked_token_instance <- marked_token_instances do
        assert marked_token_instance.metadata == nil
        assert marked_token_instance.error == ":marked_to_refetch"
      end

      assert :ok = Refetch.run(token_instances, [])

      :timer.sleep(150)

      updated_token_instances =
        Repo.all(
          from(i in Instance,
            where: i.token_contract_address_hash == ^token.contract_address_hash
          )
        )

      for updated_token_instance <- updated_token_instances do
        assert updated_token_instance.metadata == %{"name" => "nice nft"}
        assert updated_token_instance.error == nil
      end

      Application.put_env(:tesla, :adapter, Explorer.Mock.TeslaAdapter)
      Bypass.down(bypass)
    end
  end
end
