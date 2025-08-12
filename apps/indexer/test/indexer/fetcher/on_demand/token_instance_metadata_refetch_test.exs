defmodule Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetchTest do
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Token.Instance, as: TokenInstance
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.TestHelper
  alias Explorer.Utility.TokenInstanceMetadataRefetchAttempt
  alias Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch, as: TokenInstanceMetadataRefetchOnDemand

  @moduletag :capture_log

  setup :set_mox_global

  setup :verify_on_exit!

  setup %{json_rpc_named_arguments: json_rpc_named_arguments} do
    mocked_json_rpc_named_arguments = Keyword.put(json_rpc_named_arguments, :transport, EthereumJSONRPC.Mox)

    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    start_supervised!(
      {TokenInstanceMetadataRefetchOnDemand,
       [mocked_json_rpc_named_arguments, [name: TokenInstanceMetadataRefetchOnDemand]]}
    )

    %{json_rpc_named_arguments: mocked_json_rpc_named_arguments}
  end

  describe "refetch token instance metadata behaviour" do
    setup do
      Subscriber.to(:fetched_token_instance_metadata, :on_demand)
      Subscriber.to(:not_fetched_token_instance_metadata, :on_demand)

      :ok
    end

    test "token instance broadcasts fetched token instance metadata" do
      token = insert(:token, name: "Super Token", type: "ERC-721")
      token_id = 1

      token_instance =
        insert(:token_instance,
          token_id: token_id,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{}
        )
        |> Repo.preload(:token)

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      assert TokenInstanceMetadataRefetchOnDemand.trigger_refetch(token_instance) == :ok

      :timer.sleep(100)

      token_instance_from_db =
        Repo.get_by(TokenInstance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      refute is_nil(token_instance_from_db.metadata)
      assert token_instance_from_db.metadata == metadata

      assert is_nil(
               Repo.get_by(TokenInstanceMetadataRefetchAttempt,
                 token_contract_address_hash: token.contract_address_hash,
                 token_id: token_id
               )
             )

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )
    end

    test "run the update on the token instance with no metadata fetched initially" do
      token = insert(:token, name: "Super Token", type: "ERC-721")
      token_id = 1

      token_instance =
        insert(:token_instance,
          token_id: token_id,
          token_contract_address_hash: token.contract_address_hash,
          metadata: nil
        )
        |> Repo.preload(:token)

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(metadata)
           }}
        end
      )

      assert TokenInstanceMetadataRefetchOnDemand.trigger_refetch(token_instance) == :ok

      :timer.sleep(100)

      token_instance_from_db =
        Repo.get_by(TokenInstance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      assert token_instance_from_db.metadata == metadata

      assert is_nil(
               Repo.get_by(TokenInstanceMetadataRefetchAttempt,
                 token_contract_address_hash: token.contract_address_hash,
                 token_id: token_id
               )
             )

      assert_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, ^metadata]}
      )
    end

    test "updates token_instance_metadata_refetch_attempts table" do
      token = insert(:token, name: "Super Token", type: "ERC-721")
      token_id = 1

      token_instance =
        insert(:token_instance,
          token_id: token_id,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{}
        )
        |> Repo.preload(:token)

      metadata = %{"name" => "Super Token"}
      url = "http://metadata.endpoint.com"
      token_contract_address_hash_string = to_string(token.contract_address_hash)

      TestHelper.fetch_token_uri_mock(url, token_contract_address_hash_string)

      Tesla.Test.expect_tesla_call(
        times: 1,
        returns: fn %{url: ^url}, _opts ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: nil
           }}
        end
      )

      assert TokenInstanceMetadataRefetchOnDemand.trigger_refetch(token_instance) == :ok

      :timer.sleep(100)

      token_instance_from_db =
        Repo.get_by(TokenInstance, token_id: token_id, token_contract_address_hash: token.contract_address_hash)

      assert(token_instance_from_db)
      refute is_nil(token_instance_from_db.metadata)

      attempts =
        Repo.get_by(TokenInstanceMetadataRefetchAttempt,
          token_contract_address_hash: token.contract_address_hash,
          token_id: token_id
        )

      refute is_nil(attempts)

      assert attempts.retries_number == 1

      refute_receive(
        {:chain_event, :fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, %{metadata: ^metadata}]}
      )

      assert_receive(
        {:chain_event, :not_fetched_token_instance_metadata, :on_demand,
         [^token_contract_address_hash_string, ^token_id, "error"]}
      )
    end
  end
end
