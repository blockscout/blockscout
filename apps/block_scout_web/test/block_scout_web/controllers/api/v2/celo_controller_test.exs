defmodule BlockScoutWeb.API.V2.CeloControllerTest do
  use BlockScoutWeb.ConnCase

  use Utils.CompileTimeEnvHelper,
    chain_type: [:explorer, :chain_type],
    chain_identity: [:explorer, :chain_identity]

  if @chain_identity == {:optimism, :celo} do
    alias Explorer.Chain.Celo.ElectionReward

    setup do
      celo_token = insert(:token)
      usd_token = insert(:token)

      original_core_contracts_config =
        Application.get_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts)

      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
        contracts: %{
          "addresses" => %{
            "Accounts" => [],
            "Election" => [],
            "EpochRewards" => [],
            "FeeHandler" => [],
            "GasPriceMinimum" => [],
            "GoldToken" => [
              %{"address" => to_string(celo_token.contract_address_hash), "updated_at_block_number" => 0}
            ],
            "Governance" => [],
            "LockedGold" => [],
            "Reserve" => [],
            "StableToken" => [
              %{"address" => to_string(usd_token.contract_address_hash), "updated_at_block_number" => 0}
            ],
            "Validators" => []
          }
        }
      )

      original_celo_config = Application.get_env(:explorer, :celo)

      on_exit(fn ->
        Application.put_env(
          :explorer,
          Explorer.Chain.Cache.CeloCoreContracts,
          original_core_contracts_config
        )

        Application.put_env(:explorer, :celo, original_celo_config)
      end)

      {:ok, %{celo_token: celo_token, usd_token: usd_token}}
    end

    describe "/api/v2/celo/epochs" do
      test "returns empty list", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs")
        assert response = json_response(request, 200)
        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "returns epochs", %{conn: conn} do
        epoch =
          insert(:celo_epoch,
            number: 1,
            fetched?: true,
            start_block_number: 0,
            end_block_number: 17_279
          )

        request = get(conn, "/api/v2/celo/epochs")
        assert response = json_response(request, 200)
        assert [item] = response["items"]
        assert item["number"] == epoch.number
        assert item["start_block_number"] == epoch.start_block_number
        assert item["end_block_number"] == epoch.end_block_number
        assert item["is_finalized"] == true
      end
    end

    describe "/api/v2/celo/epochs/:number" do
      test "returns 404 for non-existing epoch", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs/100")
        assert %{"message" => "Not found"} = json_response(request, 404)
      end

      test "returns 422 for invalid epoch number", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs/invalid")
        assert %{"errors" => [_]} = json_response(request, 422)
      end

      test "returns unfetched epoch with null aggregated rewards", %{conn: conn} do
        insert(:celo_epoch,
          number: 1,
          fetched?: false,
          start_block_number: 0,
          end_block_number: 17_279
        )

        request = get(conn, "/api/v2/celo/epochs/1")
        assert response = json_response(request, 200)
        assert response["number"] == 1
        assert response["is_finalized"] == false
        assert response["aggregated_election_rewards"] == nil
      end

      test "returns fetched epoch with aggregated rewards", %{conn: conn} do
        insert(:celo_epoch,
          number: 1,
          fetched?: true,
          start_block_number: 0,
          end_block_number: 17_279
        )

        for type <- ElectionReward.types() do
          insert(:celo_aggregated_election_reward,
            epoch_number: 1,
            type: type,
            sum: 1000,
            count: 5
          )
        end

        request = get(conn, "/api/v2/celo/epochs/1")
        assert response = json_response(request, 200)
        assert response["number"] == 1
        assert response["is_finalized"] == true

        rewards = response["aggregated_election_rewards"]
        assert is_map(rewards)

        for type <- ElectionReward.types() do
          assert %{"total" => _, "count" => 5, "token" => _} = rewards[to_string(type)]
        end
      end

      test "returns L2 epoch with null delegated_payment in aggregated rewards", %{conn: conn} do
        # Epoch 2 starts at block 17280. Setting l2_migration_block to 17280
        # makes epoch 2 an L2 epoch (epoch_number >= migration epoch number).
        Application.put_env(:explorer, :celo, l2_migration_block: 17_280)

        insert(:celo_epoch,
          number: 2,
          fetched?: true,
          start_block_number: 17_280,
          end_block_number: 34_559
        )

        for type <- ElectionReward.types() do
          insert(:celo_aggregated_election_reward,
            epoch_number: 2,
            type: type,
            sum: 1000,
            count: 5
          )
        end

        request = get(conn, "/api/v2/celo/epochs/2")
        assert response = json_response(request, 200)
        assert response["type"] == "L2"

        rewards = response["aggregated_election_rewards"]
        assert rewards["delegated_payment"] == nil

        for type <- ElectionReward.types() -- [:delegated_payment] do
          assert %{"total" => _, "count" => 5, "token" => _} = rewards[to_string(type)]
        end
      end
    end

    describe "/api/v2/celo/epochs/:number/election-rewards/:type" do
      test "returns empty list", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs/1/election-rewards/voter")
        assert response = json_response(request, 200)
        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "returns 422 for invalid epoch number", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs/invalid/election-rewards/voter")
        assert %{"errors" => [_]} = json_response(request, 422)
      end

      test "accepts both hyphenated and underscored delegated_payment type in URL", %{conn: conn} do
        request = get(conn, "/api/v2/celo/epochs/1/election-rewards/delegated-payment")
        assert %{"items" => []} = json_response(request, 200)

        request = get(conn, "/api/v2/celo/epochs/1/election-rewards/delegated_payment")
        assert %{"items" => []} = json_response(request, 200)
      end
    end
  end
end
