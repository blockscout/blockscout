defmodule BlockScoutWeb.API.RPC.RewardControllerTest do
  use BlockScoutWeb.ConnCase

  import Explorer.Factory

  alias Explorer.Chain.{Address, Block, CeloAccount}

  describe "getvoterrewardsforgroup" do
    test "with missing voter address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "reward", "action" => "getvoterrewardsforgroup"})
        |> json_response(200)

      assert response["message"] =~ "'voterAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with missing group address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "'groupAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid voter address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => "bad_hash",
          "groupAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "Invalid voter address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid group address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "groupAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "Invalid group address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      expected_result = %{
        "rewards" => [],
        "total" => "0"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "groupAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid voter and group address", %{conn: conn} do
      %Address{hash: voter_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      insert(:celo_account, address: group_hash)

      %Block{number: block_1_number, timestamp: block_1_timestamp, hash: block_1_hash} =
        insert(:block, number: 17_280, timestamp: ~U[2022-01-01T17:42:43.162804Z])

      %Block{number: block_2_number, timestamp: block_2_timestamp, hash: block_2_hash} =
        insert(:block, number: 17_280 * 2, timestamp: ~U[2022-01-02T17:42:43.162804Z])

      insert(
        :celo_election_rewards,
        account_hash: voter_hash,
        amount: 80,
        associated_account_hash: group_hash,
        block_number: block_1_number,
        block_timestamp: block_1_timestamp,
        block_hash: block_1_hash
      )

      insert(
        :celo_election_rewards,
        account_hash: voter_hash,
        amount: 20,
        associated_account_hash: group_hash,
        block_number: block_2_number,
        block_timestamp: block_2_timestamp,
        block_hash: block_2_hash
      )

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "20",
            "blockNumber" => "34560",
            "date" => "2022-01-02T17:42:43.162804Z",
            "epochNumber" => "2"
          },
          %{
            "amount" => "80",
            "blockNumber" => "17280",
            "date" => "2022-01-01T17:42:43.162804Z",
            "epochNumber" => "1"
          }
        ],
        "total" => "100"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => to_string(voter_hash),
          "groupAddress" => to_string(group_hash)
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  describe "getvoterrewards" do
    test "with missing voter address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "reward", "action" => "getvoterrewards"})
        |> json_response(200)

      assert response["message"] =~ "'voterAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid voter address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more voter addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid voter address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more voter addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_for_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      expected_result = %{
        "rewards" => [],
        "totalRewardCelo" => "0",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid voter hash", %{conn: conn} do
      %Address{hash: voter_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: group_name} = insert(:celo_account, address: group_hash)

      %Block{number: block_1_number, timestamp: block_1_timestamp, hash: block_1_hash} =
        insert(:block, number: 17_280, timestamp: ~U[2022-01-05T17:42:43.162804Z])

      %Block{number: block_2_number, timestamp: block_2_timestamp, hash: block_2_hash} =
        insert(:block, number: 17_280 * 2, timestamp: ~U[2022-01-06T17:42:43.162804Z])

      insert(
        :celo_election_rewards,
        account_hash: voter_hash,
        amount: 80,
        associated_account_hash: group_hash,
        block_number: block_1_number,
        block_timestamp: block_1_timestamp,
        block_hash: block_1_hash
      )

      insert(
        :celo_election_rewards,
        account_hash: voter_hash,
        amount: 20,
        associated_account_hash: group_hash,
        block_number: block_2_number,
        block_timestamp: block_2_timestamp,
        block_hash: block_2_hash
      )

      expected_result = %{
        "rewards" => [
          %{
            "account" => to_string(voter_hash),
            "amount" => "80",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => group_name
          }
        ],
        "totalRewardCelo" => "80",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => to_string(voter_hash),
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = generic_rewards_for_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  describe "getvalidatorrewards" do
    test "with missing validator address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "reward", "action" => "getvalidatorrewards"})
        |> json_response(200)

      assert response["message"] =~ "'validatorAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid validator address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid validator address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more validator addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_for_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      expected_result = %{
        "rewards" => [],
        "totalRewardCelo" => "0",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid validator address", %{conn: conn} do
      %Address{hash: validator_1_hash} = insert(:address)
      %Address{hash: validator_2_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: group_name} = insert(:celo_account, address: group_hash)

      %Block{number: block_number, timestamp: block_timestamp, hash: block_hash} =
        insert(:block, number: 17_280, timestamp: ~U[2022-01-05T17:42:43.162804Z])

      insert(
        :celo_election_rewards,
        account_hash: validator_1_hash,
        amount: 150_000,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "validator"
      )

      insert(
        :celo_election_rewards,
        account_hash: validator_2_hash,
        amount: 100_000,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "validator"
      )

      expected_result = %{
        "rewards" => [
          %{
            "account" => to_string(validator_1_hash),
            "amount" => "150000",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => group_name
          }
        ],
        "totalRewardCelo" => "150000",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_1_hash),
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = generic_rewards_for_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid validator address list", %{conn: conn} do
      %Address{hash: validator_1_hash} = insert(:address)
      %Address{hash: validator_2_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: group_name} = insert(:celo_account, address: group_hash)

      %Block{number: block_number, timestamp: block_timestamp, hash: block_hash} =
        insert(:block, number: 17_280, timestamp: ~U[2022-01-05T17:42:43.162804Z])

      insert(
        :celo_election_rewards,
        account_hash: validator_1_hash,
        amount: 150_000,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "validator"
      )

      insert(
        :celo_election_rewards,
        account_hash: validator_2_hash,
        amount: 100_000,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "validator"
      )

      expected_result = %{
        "rewards" => [
          %{
            "account" => to_string(validator_1_hash),
            "amount" => "150000",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => group_name
          },
          %{
            "account" => to_string(validator_2_hash),
            "amount" => "100000",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => group_name
          }
        ],
        "totalRewardCelo" => "250000",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_1_hash) <> ", " <> to_string(validator_2_hash),
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = generic_rewards_for_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  describe "getvalidatorgrouprewards" do
    test "with missing group address", %{conn: conn} do
      response =
        conn
        |> get("/api", %{"module" => "reward", "action" => "getvalidatorgrouprewards"})
        |> json_response(200)

      assert response["message"] =~ "'groupAddress' is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid validator address hash", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => "bad_hash"
        })
        |> json_response(200)

      assert response["message"] =~ "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an invalid group address hash in the list", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => "0x0000000000000000000000000000000000000001, bad_hash"
        })
        |> json_response(200)

      assert response["message"] == "One or more group addresses are invalid"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = group_rewards_multiple_accounts_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      expected_result = %{
        "rewards" => [],
        "totalRewardCelo" => "0",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "from" => "2022-01-03 00:00:00.000000Z",
          "to" => "2022-01-06 00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid group address", %{conn: conn} do
      %Address{hash: validator_1_hash} = insert(:address)
      %Address{hash: validator_2_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: validator_1_name} = insert(:celo_account, address: validator_1_hash)
      %CeloAccount{name: validator_2_name} = insert(:celo_account, address: validator_2_hash)

      %Block{number: block_number, timestamp: block_timestamp, hash: block_hash} =
        insert(:block, number: 17_280, timestamp: ~U[2022-01-05T17:42:43.162804Z])

      insert(
        :celo_election_rewards,
        account_hash: group_hash,
        amount: 300_000,
        associated_account_hash: validator_1_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "group"
      )

      insert(
        :celo_election_rewards,
        account_hash: group_hash,
        amount: 400_000,
        associated_account_hash: validator_2_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "group"
      )

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "300000",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => to_string(group_hash),
            "validator" => validator_1_name
          },
          %{
            "amount" => "400000",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "17280",
            "epochNumber" => "1",
            "group" => to_string(group_hash),
            "validator" => validator_2_name
          }
        ],
        "totalRewardCelo" => "700000",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z"
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => to_string(group_hash),
          "from" => "2022-01-03T00:00:00.000000Z",
          "to" => "2022-01-06T00:00:00.000000Z"
        })
        |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end
  end

  defp rewards_for_group_schema do
    %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "string"},
          "block_hash" => %{"type" => "string"},
          "block_number" => %{"type" => "string"},
          "date" => %{"type" => "string"},
          "epoch_number" => %{"type" => "string"}
        }
      }
    }
  end

  defp generic_epoch_rewards_schema do
    %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "string"},
          "block_hash" => %{"type" => "string"},
          "block_number" => %{"type" => "string"},
          "date" => %{"type" => "string"},
          "epoch_number" => %{"type" => "string"},
          "group" => %{"type" => "string"}
        }
      }
    }
  end

  defp group_epoch_rewards_schema do
    %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "string"},
          "block_hash" => %{"type" => "string"},
          "block_number" => %{"type" => "string"},
          "date" => %{"type" => "string"},
          "epoch_number" => %{"type" => "string"},
          "validator" => %{"type" => "string"}
        }
      }
    }
  end

  defp group_epoch_rewards_multiple_accounts_schema do
    %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "string"},
          "block_hash" => %{"type" => "string"},
          "block_number" => %{"type" => "string"},
          "date" => %{"type" => "string"},
          "epoch_number" => %{"type" => "string"},
          "group" => %{"type" => "string"},
          "validator" => %{"type" => "string"}
        }
      }
    }
  end

  defp voter_rewards_for_group_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "properties" => %{
        "total" => %{"type" => "string"},
        "rewards" => rewards_for_group_schema()
      }
    })
  end

  defp group_rewards_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "properties" => %{
        "total_reward_celo" => %{"type" => "string"},
        "group" => %{"type" => "string"},
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "rewards" => group_epoch_rewards_schema()
      }
    })
  end

  defp group_rewards_multiple_accounts_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "properties" => %{
        "total_reward_celo" => %{"type" => "string"},
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "rewards" => group_epoch_rewards_multiple_accounts_schema()
      }
    })
  end

  defp generic_rewards_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "properties" => %{
        "total_reward_celo" => %{"type" => "string"},
        "account" => %{"type" => "string"},
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "rewards" => generic_epoch_rewards_schema()
      }
    })
  end

  defp generic_rewards_for_multiple_accounts_schema do
    resolve_schema(%{
      "type" => ["object", "null"],
      "properties" => %{
        "total_reward_celo" => %{"type" => "string"},
        "from" => %{"type" => "string"},
        "to" => %{"type" => "string"},
        "rewards" => generic_epoch_rewards_schema()
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
