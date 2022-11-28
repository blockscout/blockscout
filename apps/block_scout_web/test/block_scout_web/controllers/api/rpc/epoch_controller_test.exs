defmodule BlockScoutWeb.API.RPC.EpochControllerTest do
  use BlockScoutWeb.ConnCase

  import Explorer.Factory

  alias Explorer.Chain.{Address, Block, CeloElectionRewards, Wei}

  describe "getvoterrewards" do
    setup [:setup_epoch_data]

    test "with missing voter address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getvoterrewards"})
        |> json_response(200)

      assert response["message"] =~ "'voterAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid voter address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more voter addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "dateFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "dateTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'from' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "-1"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'to' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "0"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "groupAddress" => "0xinvalid"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid voter address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more voter addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001",
          "groupAddress" => "0x0000000000000000000000000000000000000002,0xinvalid"
        })
        |> json_response(200)

      assert response["message"] == "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'to' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{
          "celo" => "0",
          "wei" => "0"
        },
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberTo" => "#{block_number + 17279}"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'from' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{
          "celo" => "0",
          "wei" => "0"
        },
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberFrom" => "123456789"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an address that doesn't exist, but there is valid data for other address", %{conn: conn} do
      # Make sure that there's data available for other address
      %Address{hash: voter_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)

      %Block{hash: block_hash, number: block_number, timestamp: block_timestamp} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_account_epoch,
        account_hash: voter_hash,
        block_hash: block_hash,
        block_number: block_number
      )

      insert(
        :celo_election_rewards,
        account_hash: voter_hash,
        amount: 8_943_276_509_843_275_698_432_756,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash
      )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{
          "celo" => "0",
          "wei" => "0"
        },
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000002"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with missing locked/activated gold data", %{conn: conn} do
      %Address{hash: voter_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)

      %Block{hash: block_hash, number: block_number, timestamp: block_timestamp} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      %CeloElectionRewards{amount: reward_amount} =
        insert(
          :celo_election_rewards,
          account_hash: voter_hash,
          amount: 8_943_276_509_843_275_698_432_756,
          associated_account_hash: group_hash,
          block_number: block_number,
          block_timestamp: block_timestamp,
          block_hash: block_hash
        )

      expected_result = %{
        "rewards" => [
          %{
            "amounts" => %{"celo" => "8943276.509843275698432756", "wei" => "8943276509843275698432756"},
            "blockHash" => to_string(block_hash),
            "blockNumber" => to_string(block_number),
            "blockTimestamp" => block_timestamp |> DateTime.to_iso8601(),
            "epochNumber" => "902",
            "meta" => %{"groupAddress" => to_string(group_hash)},
            "rewardAddress" => to_string(voter_hash),
            "rewardAddressVotingGold" => %{"celo" => "unknown", "wei" => "unknown"},
            "rewardAddressLockedGold" => %{"celo" => "unknown", "wei" => "unknown"}
          }
        ],
        "totalRewardAmounts" => %{
          "celo" => to_string(reward_amount |> Wei.to(:ether)),
          "wei" => to_string(reward_amount)
        },
        "totalRewardCount" => "1"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => to_string(voter_hash)
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with valid voter addresses", %{
      conn: conn,
      voter_rewards_1_2_3: %{amount: reward_amount_1_2_3},
      voter_rewards_2_2_3: %{amount: reward_amount_2_2_3},
      voter_rewards_2_1_1: %{amount: reward_amount_2_1_1},
      voter_rewards_2_1_2: %{amount: reward_amount_2_1_2},
      voter_rewards_2_2_1: %{amount: reward_amount_2_2_1},
      voter_rewards_2_2_2: %{amount: reward_amount_2_2_2},
      block_1: block_1,
      block_2: block_2,
      block_3: block_3,
      group_1_hash: group_1_hash,
      group_2_hash: group_2_hash,
      voter_1_hash: voter_1_hash,
      voter_2_hash: voter_2_hash,
      account_epoch_2_1: %{total_locked_gold: locked_gold_2_1, nonvoting_locked_gold: nonvoting_gold_2_1},
      account_epoch_2_2: %{total_locked_gold: locked_gold_2_2, nonvoting_locked_gold: nonvoting_gold_2_2},
      account_epoch_1_3: %{total_locked_gold: locked_gold_1_3, nonvoting_locked_gold: nonvoting_gold_1_3},
      account_epoch_2_3: %{total_locked_gold: locked_gold_2_3, nonvoting_locked_gold: nonvoting_gold_2_3}
    } do
      # Rewards for block 3 should be excluded
      total_rewards =
        reward_amount_2_1_1
        |> Wei.sum(reward_amount_2_1_2)
        |> Wei.sum(reward_amount_2_2_1)
        |> Wei.sum(reward_amount_2_2_2)

      expected_result_first_page = %{
        "rewards" =>
          [
            {block_2, voter_2_hash, group_1_hash, reward_amount_2_1_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_2, voter_2_hash, group_2_hash, reward_amount_2_2_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_1, voter_2_hash, group_1_hash, reward_amount_2_1_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:voter, tuple) end),
        "totalRewardAmounts" => %{
          "celo" => to_string(Wei.to(total_rewards, :ether)),
          "wei" => to_string(total_rewards)
        },
        "totalRewardCount" => "4"
      }

      response_first_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => to_string(voter_2_hash),
          "page_size" => "3",
          "dateFrom" => "#{block_1.timestamp}",
          "dateTo" => "#{block_2.timestamp}"
        })
        |> json_response(200)

      assert response_first_page["result"] == expected_result_first_page
      assert response_first_page["status"] == "1"
      assert response_first_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_first_page)

      expected_result_second_page = %{
        "rewards" =>
          [
            {block_1, voter_2_hash, group_2_hash, reward_amount_2_2_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:voter, tuple) end),
        "totalRewardAmounts" => %{
          "celo" => to_string(Wei.to(total_rewards, :ether)),
          "wei" => to_string(total_rewards)
        },
        "totalRewardCount" => "4"
      }

      response_second_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => to_string(voter_2_hash),
          "page_number" => "2",
          "page_size" => "3",
          "blockNumberFrom" => "#{block_1.number - 1}",
          "blockNumberTo" => "#{block_2.number + 1}"
        })
        |> json_response(200)

      assert response_second_page["result"] == expected_result_second_page
      assert response_second_page["status"] == "1"
      assert response_second_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_second_page)

      total_rewards_single_group_multiple_voters =
        reward_amount_1_2_3
        |> Wei.sum(reward_amount_2_2_3)

      expected_result_single_group_multiple_voters = %{
        "rewards" =>
          [
            {block_3, voter_1_hash, group_2_hash, reward_amount_1_2_3, locked_gold_1_3, nonvoting_gold_1_3},
            {block_3, voter_2_hash, group_2_hash, reward_amount_2_2_3, locked_gold_2_3, nonvoting_gold_2_3}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:voter, tuple) end),
        "totalRewardAmounts" => %{
          "celo" => to_string(Wei.to(total_rewards_single_group_multiple_voters, :ether)),
          "wei" => to_string(total_rewards_single_group_multiple_voters)
        },
        "totalRewardCount" => "2"
      }

      response_single_group_multiple_voters =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvoterrewards",
          "voterAddress" => "#{to_string(voter_2_hash)},#{to_string(voter_1_hash)}",
          "groupAddress" => to_string(group_2_hash),
          "blockNumberFrom" => "#{block_3.number}",
          "blockNumberTo" => "#{block_3.number}"
        })
        |> json_response(200)

      assert response_single_group_multiple_voters["result"] == expected_result_single_group_multiple_voters
      assert response_single_group_multiple_voters["status"] == "1"
      assert response_single_group_multiple_voters["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_single_group_multiple_voters)
    end
  end

  describe "getvalidatorrewards" do
    setup [:setup_epoch_data]

    test "with missing validator address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getvalidatorrewards"})
        |> json_response(200)

      assert response["message"] =~ "'validatorAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid voter address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "dateFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "dateTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'from' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "-1"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'to' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "0"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "groupAddress" => "0xinvalid"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid validator address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001",
          "groupAddress" => "0x0000000000000000000000000000000000000002,0xinvalid"
        })
        |> json_response(200)

      assert response["message"] == "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'to' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberTo" => "#{block_number + 17279}"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'from' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberFrom" => "123456789"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an address that doesn't exist, but there is valid data for other address", %{
      conn: conn,
      block_3: %{number: block_number, hash: block_hash}
    } do
      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x1000000000000000000000000000000000000002"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with missing locked/activated gold data", %{conn: conn} do
      %Address{hash: validator_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)

      %Block{hash: block_hash, number: block_number, timestamp: block_timestamp} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      %CeloElectionRewards{amount: reward_amount} =
        insert(
          :celo_election_rewards,
          account_hash: validator_hash,
          amount: 8_943_276_509_843_275_698_432_756,
          associated_account_hash: group_hash,
          block_number: block_number,
          block_timestamp: block_timestamp,
          block_hash: block_hash,
          reward_type: "validator"
        )

      expected_result = %{
        "rewards" => [
          %{
            "amounts" => %{"cUSD" => "8943276.509843275698432756"},
            "blockHash" => to_string(block_hash),
            "blockNumber" => to_string(block_number),
            "blockTimestamp" => block_timestamp |> DateTime.to_iso8601(),
            "epochNumber" => "902",
            "meta" => %{"groupAddress" => to_string(group_hash)},
            "rewardAddress" => to_string(validator_hash),
            "rewardAddressVotingGold" => %{"celo" => "unknown", "wei" => "unknown"},
            "rewardAddressLockedGold" => %{"celo" => "unknown", "wei" => "unknown"}
          }
        ],
        "totalRewardAmounts" => %{"cUSD" => to_string(reward_amount |> Wei.to(:ether))},
        "totalRewardCount" => "1"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_hash)
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with valid validator addresses", %{
      conn: conn,
      validator_rewards_1_2_3: %{amount: reward_amount_1_2_3},
      validator_rewards_2_2_3: %{amount: reward_amount_2_2_3},
      validator_rewards_2_1_1: %{amount: reward_amount_2_1_1},
      validator_rewards_2_1_2: %{amount: reward_amount_2_1_2},
      validator_rewards_2_2_1: %{amount: reward_amount_2_2_1},
      validator_rewards_2_2_2: %{amount: reward_amount_2_2_2},
      block_1: block_1,
      block_2: block_2,
      block_3: block_3,
      group_1_hash: group_1_hash,
      group_2_hash: group_2_hash,
      voter_1_hash: validator_1_hash,
      voter_2_hash: validator_2_hash,
      account_epoch_2_1: %{total_locked_gold: locked_gold_2_1, nonvoting_locked_gold: nonvoting_gold_2_1},
      account_epoch_2_2: %{total_locked_gold: locked_gold_2_2, nonvoting_locked_gold: nonvoting_gold_2_2},
      account_epoch_1_3: %{total_locked_gold: locked_gold_1_3, nonvoting_locked_gold: nonvoting_gold_1_3},
      account_epoch_2_3: %{total_locked_gold: locked_gold_2_3, nonvoting_locked_gold: nonvoting_gold_2_3}
    } do
      # Rewards for block 3 should be excluded
      total_rewards =
        reward_amount_2_1_1
        |> Wei.sum(reward_amount_2_1_2)
        |> Wei.sum(reward_amount_2_2_1)
        |> Wei.sum(reward_amount_2_2_2)

      expected_result_first_page = %{
        "rewards" =>
          [
            {block_2, validator_2_hash, group_1_hash, reward_amount_2_1_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_2, validator_2_hash, group_2_hash, reward_amount_2_2_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_1, validator_2_hash, group_1_hash, reward_amount_2_1_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:validator, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards |> Wei.to(:ether))},
        "totalRewardCount" => "4"
      }

      response_first_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_2_hash),
          "page_size" => "3",
          "dateFrom" => "#{to_string(block_1.timestamp)}",
          "dateTo" => "#{to_string(block_2.timestamp)}"
        })
        |> json_response(200)

      assert response_first_page["result"] == expected_result_first_page
      assert response_first_page["status"] == "1"
      assert response_first_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_first_page)

      expected_result_second_page = %{
        "rewards" =>
          [
            {block_1, validator_2_hash, group_2_hash, reward_amount_2_2_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:validator, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards |> Wei.to(:ether))},
        "totalRewardCount" => "4"
      }

      response_second_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_2_hash),
          "page_number" => "2",
          "page_size" => "3",
          "blockNumberFrom" => "#{block_1.number - 1}",
          "blockNumberTo" => "#{block_2.number + 1}"
        })
        |> json_response(200)

      assert response_second_page["result"] == expected_result_second_page
      assert response_second_page["status"] == "1"
      assert response_second_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_second_page)

      total_rewards_single_group_multiple_voters =
        reward_amount_1_2_3
        |> Wei.sum(reward_amount_2_2_3)

      expected_result_single_group_multiple_voters = %{
        "rewards" =>
          [
            {block_3, validator_1_hash, group_2_hash, reward_amount_1_2_3, locked_gold_1_3, nonvoting_gold_1_3},
            {block_3, validator_2_hash, group_2_hash, reward_amount_2_2_3, locked_gold_2_3, nonvoting_gold_2_3}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:validator, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards_single_group_multiple_voters |> Wei.to(:ether))},
        "totalRewardCount" => "2"
      }

      response_single_group_multiple_voters =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "#{to_string(validator_2_hash)},#{to_string(validator_1_hash)}",
          "groupAddress" => to_string(group_2_hash),
          "blockNumberFrom" => "#{block_3.number}",
          "blockNumberTo" => "#{block_3.number}"
        })
        |> json_response(200)

      assert response_single_group_multiple_voters["result"] == expected_result_single_group_multiple_voters
      assert response_single_group_multiple_voters["status"] == "1"
      assert response_single_group_multiple_voters["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_single_group_multiple_voters)
    end
  end

  describe "getgrouprewards" do
    setup [:setup_epoch_data]

    test "with missing group address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getgrouprewards"})
        |> json_response(200)

      assert response["message"] =~ "'groupAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'blockNumberTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for block number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateFrom' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "dateFrom" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid 'dateTo' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "dateTo" => "invalid"
        })
        |> json_response(200)

      assert response["message"] =~ "Wrong format for date provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'from' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberFrom" => "-1"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with a <1 'to' param", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "blockNumberTo" => "0"
        })
        |> json_response(200)

      assert response["message"] =~ "Block number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid validator address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "validatorAddress" => "0xinvalid"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid group address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an invalid validator address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001",
          "validatorAddress" => "0x0000000000000000000000000000000000000002,0xinvalid"
        })
        |> json_response(200)

      assert response["message"] == "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'to' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberTo" => "#{block_number + 17279}"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with provided only 'from' parameter", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000002",
          "blockNumberFrom" => "123456789"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with an address that doesn't exist, but there is valid data for other address", %{
      conn: conn,
      block_3: %{number: block_number, hash: block_hash}
    } do
      insert(
        :celo_epoch_rewards,
        block_number: block_number,
        block_hash: block_hash
      )

      expected_result = %{
        "rewards" => [],
        "totalRewardAmounts" => %{"cUSD" => "0"},
        "totalRewardCount" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "0x1000000000000000000000000000000000000002"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with missing locked/activated gold data", %{conn: conn} do
      %Address{hash: validator_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)

      %Block{hash: block_hash, number: block_number, timestamp: block_timestamp} =
        insert(
          :block,
          number: 17280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      %CeloElectionRewards{amount: reward_amount} =
        insert(
          :celo_election_rewards,
          account_hash: group_hash,
          amount: 8_943_276_509_843_275_698_432_756,
          associated_account_hash: validator_hash,
          block_number: block_number,
          block_timestamp: block_timestamp,
          block_hash: block_hash,
          reward_type: "group"
        )

      expected_result = %{
        "rewards" => [
          %{
            "amounts" => %{"cUSD" => "8943276.509843275698432756"},
            "blockHash" => to_string(block_hash),
            "blockNumber" => to_string(block_number),
            "blockTimestamp" => block_timestamp |> DateTime.to_iso8601(),
            "epochNumber" => "902",
            "meta" => %{"validatorAddress" => to_string(validator_hash)},
            "rewardAddress" => to_string(group_hash),
            "rewardAddressVotingGold" => %{"celo" => "unknown", "wei" => "unknown"},
            "rewardAddressLockedGold" => %{"celo" => "unknown", "wei" => "unknown"}
          }
        ],
        "totalRewardAmounts" => %{"cUSD" => to_string(reward_amount |> Wei.to(:ether))},
        "totalRewardCount" => "1"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => to_string(group_hash)
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response)
    end

    test "with valid group addresses", %{
      conn: conn,
      group_rewards_1_2_3: %{amount: reward_amount_1_2_3},
      group_rewards_2_2_3: %{amount: reward_amount_2_2_3},
      group_rewards_2_1_1: %{amount: reward_amount_2_1_1},
      group_rewards_2_1_2: %{amount: reward_amount_2_1_2},
      group_rewards_2_2_1: %{amount: reward_amount_2_2_1},
      group_rewards_2_2_2: %{amount: reward_amount_2_2_2},
      block_1: block_1,
      block_2: block_2,
      block_3: block_3,
      group_1_hash: validator_1_hash,
      group_2_hash: validator_2_hash,
      voter_1_hash: group_1_hash,
      voter_2_hash: group_2_hash,
      account_epoch_2_1: %{total_locked_gold: locked_gold_2_1, nonvoting_locked_gold: nonvoting_gold_2_1},
      account_epoch_2_2: %{total_locked_gold: locked_gold_2_2, nonvoting_locked_gold: nonvoting_gold_2_2},
      account_epoch_1_3: %{total_locked_gold: locked_gold_1_3, nonvoting_locked_gold: nonvoting_gold_1_3},
      account_epoch_2_3: %{total_locked_gold: locked_gold_2_3, nonvoting_locked_gold: nonvoting_gold_2_3}
    } do
      # Rewards for block 3 should be excluded
      total_rewards =
        reward_amount_2_1_1
        |> Wei.sum(reward_amount_2_1_2)
        |> Wei.sum(reward_amount_2_2_1)
        |> Wei.sum(reward_amount_2_2_2)

      expected_result_first_page = %{
        "rewards" =>
          [
            {block_2, group_2_hash, validator_1_hash, reward_amount_2_1_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_2, group_2_hash, validator_2_hash, reward_amount_2_2_2, locked_gold_2_2, nonvoting_gold_2_2},
            {block_1, group_2_hash, validator_1_hash, reward_amount_2_1_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:group, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards |> Wei.to(:ether))},
        "totalRewardCount" => "4"
      }

      response_first_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => to_string(group_2_hash),
          "page_size" => "3",
          "dateFrom" => "#{block_1.timestamp}",
          "dateTo" => "#{block_2.timestamp}"
        })
        |> json_response(200)

      assert response_first_page["result"] == expected_result_first_page
      assert response_first_page["status"] == "1"
      assert response_first_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_first_page)

      expected_result_second_page = %{
        "rewards" =>
          [
            {block_1, group_2_hash, validator_2_hash, reward_amount_2_2_1, locked_gold_2_1, nonvoting_gold_2_1}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:group, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards |> Wei.to(:ether))},
        "totalRewardCount" => "4"
      }

      response_second_page =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => to_string(group_2_hash),
          "page_number" => "2",
          "page_size" => "3",
          "blockNumberFrom" => "#{block_1.number - 1}",
          "blockNumberTo" => "#{block_2.number + 1}"
        })
        |> json_response(200)

      assert response_second_page["result"] == expected_result_second_page
      assert response_second_page["status"] == "1"
      assert response_second_page["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_second_page)

      total_rewards_single_validator_multiple_voters =
        reward_amount_1_2_3
        |> Wei.sum(reward_amount_2_2_3)

      expected_result_single_validator_multiple_voters = %{
        "rewards" =>
          [
            {block_3, group_1_hash, validator_2_hash, reward_amount_1_2_3, locked_gold_1_3, nonvoting_gold_1_3},
            {block_3, group_2_hash, validator_2_hash, reward_amount_2_2_3, locked_gold_2_3, nonvoting_gold_2_3}
          ]
          |> Enum.map(fn tuple -> map_tuple_to_api_item(:group, tuple) end),
        "totalRewardAmounts" => %{"cUSD" => to_string(total_rewards_single_validator_multiple_voters |> Wei.to(:ether))},
        "totalRewardCount" => "2"
      }

      response_single_group_multiple_validators =
        conn
        |> get("/api", %{
          "module" => "epoch",
          "action" => "getgrouprewards",
          "groupAddress" => "#{to_string(group_2_hash)},#{to_string(group_1_hash)}",
          "validatorAddress" => to_string(validator_2_hash),
          "blockNumberFrom" => "#{block_3.number}",
          "blockNumberTo" => "#{block_3.number}"
        })
        |> json_response(200)

      assert response_single_group_multiple_validators["result"] == expected_result_single_validator_multiple_voters
      assert response_single_group_multiple_validators["status"] == "1"
      assert response_single_group_multiple_validators["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(rewards_schema(), response_single_group_multiple_validators)
    end
  end

  describe "getepoch" do
    test "with missing epoch number", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getepoch"})
        |> json_response(200)

      assert response["message"] =~ "'epochNumber' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(epoch_block_schema(), response)
    end

    test "with invalid epoch number", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getepoch", "epochNumber" => "invalid"})
        |> json_response(200)

      assert response["message"] =~ "Wrong format for epoch number provided"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(epoch_block_schema(), response)
    end

    test "with epoch number < 1", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getepoch", "epochNumber" => "-1"})
        |> json_response(200)

      assert response["message"] =~ "Epoch number must be greater than 0"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]

      assert :ok = ExJsonSchema.Validator.validate(epoch_block_schema(), response)
    end

    test "with epoch number for which there is no data", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getepoch", "epochNumber" => "920"})
        |> json_response(200)

      assert response["result"] == nil
      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(epoch_block_schema(), response)
    end

    test "with valid epoch number", %{conn: conn} do
      %Block{hash: block_hash, number: block_number} =
        insert(
          :block,
          number: 17280 * 920,
          timestamp: ~U[2022-10-30T18:53:12.162804Z]
        )

      insert(
        :celo_epoch_rewards,
        epoch_number: 920,
        block_number: block_number,
        block_hash: block_hash,
        voter_target_epoch_rewards: 1,
        community_target_epoch_rewards: 2,
        carbon_offsetting_target_epoch_rewards: 3,
        target_total_supply: 4,
        rewards_multiplier: 5,
        rewards_multiplier_max: 6,
        rewards_multiplier_under: 7,
        rewards_multiplier_over: 8,
        target_voting_yield: 9,
        target_voting_yield_max: 10,
        target_voting_yield_adjustment_factor: 11,
        target_voting_fraction: 12,
        voting_fraction: 13,
        total_locked_gold: 14,
        total_non_voting: 15,
        total_votes: 16,
        electable_validators_max: 17,
        reserve_gold_balance: 18,
        gold_total_supply: 19,
        stable_usd_total_supply: 20,
        reserve_bolster: 21,
        validator_target_epoch_rewards: 22
      )

      response =
        conn
        |> get("/api", %{"module" => "epoch", "action" => "getepoch", "epochNumber" => "920"})
        |> json_response(200)

      assert response["result"] == %{
               "blockNumber" => to_string(block_number),
               "blockHash" => to_string(block_hash),
               "carbonOffsettingTargetEpochRewards" => "3",
               "communityTargetEpochRewards" => "2",
               "electableValidatorsMax" => "17",
               "goldTotalSupply" => "19",
               "reserveBolster" => "21",
               "reserveGoldBalance" => "18",
               "rewardsMultiplier" => "5",
               "rewardsMultiplierMax" => "6",
               "rewardsMultiplierOver" => "8",
               "rewardsMultiplierUnder" => "7",
               "stableUsdTotalSupply" => "20",
               "targetTotalSupply" => "4",
               "targetVotingFraction" => "12",
               "targetVotingYield" => "9",
               "targetVotingYieldAdjustmentFactor" => "11",
               "targetVotingYieldMax" => "10",
               "totalLockedGold" => "14",
               "totalNonVoting" => "15",
               "totalVotes" => "16",
               "validatorTargetEpochRewards" => "22",
               "voterTargetEpochRewards" => "1",
               "votingFraction" => "13"
             }

      assert response["status"] == "1"
      assert response["message"] == "OK"

      assert :ok = ExJsonSchema.Validator.validate(epoch_block_schema(), response)
    end
  end

  defp setup_epoch_data(context) do
    max_reward_base = 1_000_000_000_000_000_000

    %Address{hash: voter_1_hash} = insert(:address)
    %Address{hash: voter_2_hash} = insert(:address)
    %Address{hash: group_1_hash} = insert(:address)
    %Address{hash: group_2_hash} = insert(:address)

    block_1 =
      insert(
        :block,
        number: 17280 * 902,
        timestamp: ~U[2022-10-12T18:53:12.162804Z]
      )

    block_2 =
      insert(
        :block,
        number: 17280 * 903,
        timestamp: ~U[2022-10-13T18:53:12.162804Z]
      )

    block_3 =
      insert(
        :block,
        number: 17280 * 904,
        timestamp: ~U[2022-10-14T18:53:12.162804Z]
      )

    account_epoch_1_1 =
      insert(
        :celo_account_epoch,
        account_hash: voter_1_hash,
        block_hash: block_1.hash,
        block_number: block_1.number
      )

    account_epoch_1_2 =
      insert(
        :celo_account_epoch,
        account_hash: voter_1_hash,
        block_hash: block_2.hash,
        block_number: block_2.number
      )

    account_epoch_1_3 =
      insert(
        :celo_account_epoch,
        account_hash: voter_1_hash,
        block_hash: block_3.hash,
        block_number: block_3.number
      )

    account_epoch_2_1 =
      insert(
        :celo_account_epoch,
        account_hash: voter_2_hash,
        block_hash: block_1.hash,
        block_number: block_1.number
      )

    account_epoch_2_2 =
      insert(
        :celo_account_epoch,
        account_hash: voter_2_hash,
        block_hash: block_2.hash,
        block_number: block_2.number
      )

    account_epoch_2_3 =
      insert(
        :celo_account_epoch,
        account_hash: voter_2_hash,
        block_hash: block_3.hash,
        block_number: block_3.number
      )

    voter_rewards_1_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 1 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_1_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 2 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_1_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 3 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_1_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 4 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_1_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 5 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_1_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 6 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 7 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 8 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 9 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 10 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 11 * :rand.uniform_real()),
        reward_type: "voter"
      )

    voter_rewards_2_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 12 * :rand.uniform_real()),
        reward_type: "voter"
      )

    validator_rewards_1_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 1 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_1_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 2 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_1_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 3 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_1_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 4 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_1_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 5 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_1_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 6 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 7 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 8 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 9 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 10 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 11 * :rand.uniform_real()),
        reward_type: "validator"
      )

    validator_rewards_2_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 12 * :rand.uniform_real()),
        reward_type: "validator"
      )

    group_rewards_1_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 1 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_1_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 2 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_1_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 3 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_1_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 4 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_1_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 5 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_1_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_1_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 6 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_1_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 7 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_1_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 8 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_1_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_1_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 9 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_2_1 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_1.number,
        block_timestamp: block_1.timestamp,
        block_hash: block_1.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 10 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_2_2 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_2.number,
        block_timestamp: block_2.timestamp,
        block_hash: block_2.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 11 * :rand.uniform_real()),
        reward_type: "group"
      )

    group_rewards_2_2_3 =
      insert(
        :celo_election_rewards,
        account_hash: voter_2_hash,
        associated_account_hash: group_2_hash,
        block_number: block_3.number,
        block_timestamp: block_3.timestamp,
        block_hash: block_3.hash,
        amount: round(Enum.random(1_000_000_000_000..max_reward_base) * 12 * :rand.uniform_real()),
        reward_type: "group"
      )

    Map.merge(context, %{
      block_1: block_1,
      block_2: block_2,
      block_3: block_3,
      voter_1_hash: voter_1_hash,
      voter_2_hash: voter_2_hash,
      group_1_hash: group_1_hash,
      group_2_hash: group_2_hash,
      account_epoch_1_1: account_epoch_1_1,
      account_epoch_1_2: account_epoch_1_2,
      account_epoch_1_3: account_epoch_1_3,
      account_epoch_2_1: account_epoch_2_1,
      account_epoch_2_2: account_epoch_2_2,
      account_epoch_2_3: account_epoch_2_3,
      voter_rewards_1_1_1: voter_rewards_1_1_1,
      voter_rewards_1_1_2: voter_rewards_1_1_2,
      voter_rewards_1_1_3: voter_rewards_1_1_3,
      voter_rewards_1_2_1: voter_rewards_1_2_1,
      voter_rewards_1_2_2: voter_rewards_1_2_2,
      voter_rewards_1_2_3: voter_rewards_1_2_3,
      voter_rewards_2_1_1: voter_rewards_2_1_1,
      voter_rewards_2_1_2: voter_rewards_2_1_2,
      voter_rewards_2_1_3: voter_rewards_2_1_3,
      voter_rewards_2_2_1: voter_rewards_2_2_1,
      voter_rewards_2_2_2: voter_rewards_2_2_2,
      voter_rewards_2_2_3: voter_rewards_2_2_3,
      validator_rewards_1_1_1: validator_rewards_1_1_1,
      validator_rewards_1_1_2: validator_rewards_1_1_2,
      validator_rewards_1_1_3: validator_rewards_1_1_3,
      validator_rewards_1_2_1: validator_rewards_1_2_1,
      validator_rewards_1_2_2: validator_rewards_1_2_2,
      validator_rewards_1_2_3: validator_rewards_1_2_3,
      validator_rewards_2_1_1: validator_rewards_2_1_1,
      validator_rewards_2_1_2: validator_rewards_2_1_2,
      validator_rewards_2_1_3: validator_rewards_2_1_3,
      validator_rewards_2_2_1: validator_rewards_2_2_1,
      validator_rewards_2_2_2: validator_rewards_2_2_2,
      validator_rewards_2_2_3: validator_rewards_2_2_3,
      group_rewards_1_1_1: group_rewards_1_1_1,
      group_rewards_1_1_2: group_rewards_1_1_2,
      group_rewards_1_1_3: group_rewards_1_1_3,
      group_rewards_1_2_1: group_rewards_1_2_1,
      group_rewards_1_2_2: group_rewards_1_2_2,
      group_rewards_1_2_3: group_rewards_1_2_3,
      group_rewards_2_1_1: group_rewards_2_1_1,
      group_rewards_2_1_2: group_rewards_2_1_2,
      group_rewards_2_1_3: group_rewards_2_1_3,
      group_rewards_2_2_1: group_rewards_2_2_1,
      group_rewards_2_2_2: group_rewards_2_2_2,
      group_rewards_2_2_3: group_rewards_2_2_3
    })
  end

  defp map_tuple_to_api_item(:voter, {block, voter_hash, group_hash, reward_amount, locked_gold, nonvoting_locked_gold}) do
    activated_gold = locked_gold |> Wei.sub(nonvoting_locked_gold)

    %{
      "amounts" => %{"celo" => to_string(reward_amount |> Wei.to(:ether)), "wei" => to_string(reward_amount)},
      "blockHash" => to_string(block.hash),
      "blockNumber" => to_string(block.number),
      "blockTimestamp" => block.timestamp |> DateTime.to_iso8601(),
      "epochNumber" => to_string(div(block.number, 17280)),
      "meta" => %{
        "groupAddress" => to_string(group_hash)
      },
      "rewardAddressVotingGold" => %{
        "celo" => to_string(activated_gold |> Wei.to(:ether)),
        "wei" => to_string(activated_gold)
      },
      "rewardAddress" => to_string(voter_hash),
      "rewardAddressLockedGold" => %{
        "celo" => to_string(locked_gold |> Wei.to(:ether)),
        "wei" => to_string(locked_gold)
      }
    }
  end

  defp map_tuple_to_api_item(
         :validator,
         {block, validator_hash, group_hash, reward_amount, locked_gold, nonvoting_locked_gold}
       ) do
    activated_gold = locked_gold |> Wei.sub(nonvoting_locked_gold)

    %{
      "amounts" => %{"cUSD" => to_string(reward_amount |> Wei.to(:ether))},
      "blockHash" => to_string(block.hash),
      "blockNumber" => to_string(block.number),
      "blockTimestamp" => block.timestamp |> DateTime.to_iso8601(),
      "epochNumber" => to_string(div(block.number, 17280)),
      "meta" => %{
        "groupAddress" => to_string(group_hash)
      },
      "rewardAddressVotingGold" => %{
        "celo" => to_string(activated_gold |> Wei.to(:ether)),
        "wei" => to_string(activated_gold)
      },
      "rewardAddress" => to_string(validator_hash),
      "rewardAddressLockedGold" => %{
        "celo" => to_string(locked_gold |> Wei.to(:ether)),
        "wei" => to_string(locked_gold)
      }
    }
  end

  defp map_tuple_to_api_item(
         :group,
         {block, group_hash, validator_hash, reward_amount, locked_gold, nonvoting_locked_gold}
       ) do
    activated_gold = locked_gold |> Wei.sub(nonvoting_locked_gold)

    %{
      "amounts" => %{"cUSD" => to_string(reward_amount |> Wei.to(:ether))},
      "blockHash" => to_string(block.hash),
      "blockNumber" => to_string(block.number),
      "blockTimestamp" => block.timestamp |> DateTime.to_iso8601(),
      "epochNumber" => to_string(div(block.number, 17280)),
      "meta" => %{
        "validatorAddress" => to_string(validator_hash)
      },
      "rewardAddressVotingGold" => %{
        "celo" => to_string(activated_gold |> Wei.to(:ether)),
        "wei" => to_string(activated_gold)
      },
      "rewardAddress" => to_string(group_hash),
      "rewardAddressLockedGold" => %{
        "celo" => to_string(locked_gold |> Wei.to(:ether)),
        "wei" => to_string(locked_gold)
      }
    }
  end

  defp epoch_block_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "required" => [
        "blockHash",
        "blockNumber",
        "validatorTargetEpochRewards",
        "voterTargetEpochRewards",
        "communityTargetEpochRewards",
        "carbonOffsettingTargetEpochRewards",
        "targetTotalSupply",
        "rewardsMultiplier",
        "rewardsMultiplierMax",
        "rewardsMultiplierUnder",
        "rewardsMultiplierOver",
        "targetVotingYield",
        "targetVotingYieldMax",
        "targetVotingYieldAdjustmentFactor",
        "targetVotingFraction",
        "votingFraction",
        "totalLockedGold",
        "totalNonVoting",
        "totalVotes",
        "electableValidatorsMax",
        "reserveGoldBalance",
        "goldTotalSupply",
        "stableUsdTotalSupply",
        "reserveBolster"
      ],
      "properties" => %{
        "blockHash" => %{"type" => "string"},
        "blockNumber" => %{"type" => "string"},
        "validatorTargetEpochRewards" => %{"type" => "string"},
        "voterTargetEpochRewards" => %{"type" => "string"},
        "communityTargetEpochRewards" => %{"type" => "string"},
        "carbonOffsettingTargetEpochRewards" => %{"type" => "string"},
        "targetTotalSupply" => %{"type" => "string"},
        "rewardsMultiplier" => %{"type" => "string"},
        "rewardsMultiplierMax" => %{"type" => "string"},
        "rewardsMultiplierUnder" => %{"type" => "string"},
        "rewardsMultiplierOver" => %{"type" => "string"},
        "targetVotingYield" => %{"type" => "string"},
        "targetVotingYieldMax" => %{"type" => "string"},
        "targetVotingYieldAdjustmentFactor" => %{"type" => "string"},
        "targetVotingFraction" => %{"type" => "string"},
        "votingFraction" => %{"type" => "string"},
        "totalLockedGold" => %{"type" => "string"},
        "totalNonVoting" => %{"type" => "string"},
        "totalVotes" => %{"type" => "string"},
        "electableValidatorsMax" => %{"type" => "string"},
        "reserveGoldBalance" => %{"type" => "string"},
        "goldTotalSupply" => %{"type" => "string"},
        "stableUsdTotalSupply" => %{"type" => "string"},
        "reserveBolster" => %{"type" => "string"}
      }
    })
  end

  defp rewards_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "required" => ["totalRewardAmounts", "totalRewardCount", "rewards"],
      "properties" => %{
        "totalRewardAmounts" => %{
          "type" => "object",
          "properties" => %{
            "celo" => %{"type" => "string"},
            "wei" => %{"type" => "string"},
            "cusd" => %{"type" => "string"}
          }
        },
        "totalRewardCount" => %{"type" => "string"},
        "rewards" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => [
              "blockHash",
              "blockNumber",
              "blockTimestamp",
              "epochNumber",
              "rewardAddress",
              "rewardAddressLockedGold",
              "rewardAddressVotingGold",
              "meta",
              "amounts"
            ],
            "properties" => %{
              "blockHash" => %{"type" => "string"},
              "blockNumber" => %{"type" => "string"},
              "epochNumber" => %{"type" => "string"},
              "rewardAddress" => %{"type" => "string"},
              "rewardAddressLockedGold" => %{
                "type" => "object",
                "properties" => %{
                  "celo" => %{"type" => "string"},
                  "cusd" => %{"type" => "string"},
                  "wei" => %{"type" => "string"}
                }
              },
              "rewardAddressVotingGold" => %{
                "type" => "object",
                "properties" => %{
                  "celo" => %{"type" => "string"},
                  "wei" => %{"type" => "string"},
                  "cusd" => %{"type" => "string"}
                }
              },
              "meta" => %{
                "type" => "object",
                "properties" => %{
                  "groupAddress" => %{"type" => "string"},
                  "validatorAddress" => %{"type" => "string"}
                }
              },
              "blockTimestamp" => %{"type" => "string"},
              "totalRewardAmounts" => %{
                "type" => "object",
                "properties" => %{
                  "celo" => %{"type" => "string"},
                  "wei" => %{"type" => "string"},
                  "cusd" => %{"type" => "string"}
                }
              }
            }
          }
        }
      }
    })
  end

  defp resolve_schema(result) do
    %{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"}
      }
    }
    |> put_in(["properties", "result"], result)
    |> ExJsonSchema.Schema.resolve()
  end
end
