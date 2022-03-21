defmodule BlockScoutWeb.API.RPC.RewardControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.{SetupValidatorAndGroupRewardsTest, SetupVoterRewardsTest}

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
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewardsforgroup",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "groupAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "Voter or group address does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = voter_rewards_for_group_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid voter and group address", %{conn: conn} do
      {
        voter_hash,
        group_hash,
        block_2_hash,
        block_3_hash,
        block_5_hash,
        block_7_hash
      } = SetupVoterRewardsTest.setup_for_group()

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "80",
            "blockHash" => to_string(block_2_hash),
            "blockNumber" => "10696320",
            "date" => "2022-01-01T17:42:43.162804Z",
            "epochNumber" => "619"
          },
          %{
            "amount" => "20",
            "blockHash" => to_string(block_3_hash),
            "blockNumber" => "10713600",
            "date" => "2022-01-02T17:42:43.162804Z",
            "epochNumber" => "620"
          },
          %{
            "amount" => "75",
            "blockHash" => to_string(block_5_hash),
            "blockNumber" => "10730880",
            "date" => "2022-01-03T17:42:43.162804Z",
            "epochNumber" => "621"
          },
          %{
            "amount" => "0",
            "blockHash" => to_string(block_7_hash),
            "blockNumber" => "10748160",
            "date" => "2022-01-04T17:42:43.162804Z",
            "epochNumber" => "622"
          }
        ],
        "total" => "175"
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

      assert response["message"] =~ "Invalid voter address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "Voter address does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid voter and group address", %{conn: conn} do
      {voter_address_1_hash, group_address_1_hash, group_address_2_hash} = SetupVoterRewardsTest.setup_for_all_groups()

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "75",
            "date" => "2022-01-03T17:42:43.162804Z",
            "blockNumber" => "10730880",
            "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000003",
            "epochNumber" => "621",
            "group" => to_string(group_address_1_hash)
          },
          %{
            "amount" => "31",
            "date" => "2022-01-04T17:42:43.162804Z",
            "blockNumber" => "10748160",
            "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000004",
            "epochNumber" => "622",
            "group" => to_string(group_address_1_hash)
          },
          %{
            "amount" => "77",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "10765440",
            "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000005",
            "epochNumber" => "623",
            "group" => to_string(group_address_1_hash)
          },
          %{
            "amount" => "39",
            "date" => "2022-01-04T17:42:43.162804Z",
            "blockNumber" => "10748160",
            "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000004",
            "epochNumber" => "622",
            "group" => to_string(group_address_2_hash)
          },
          %{
            "amount" => "78",
            "date" => "2022-01-05T17:42:43.162804Z",
            "blockNumber" => "10765440",
            "blockHash" => "0x0000000000000000000000000000000000000000000000000000000000000005",
            "epochNumber" => "623",
            "group" => to_string(group_address_2_hash)
          }
        ],
        "totalRewardCelo" => "300",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z",
        "account" => to_string(voter_address_1_hash)
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvoterrewards",
          "voterAddress" => to_string(voter_address_1_hash),
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

      assert response["message"] =~ "Invalid validator address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "Validator address does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = generic_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid validator address", %{conn: conn} do
      {validator_address_1_hash, group_address_1_hash, block_2_hash, block_3_hash} =
        SetupValidatorAndGroupRewardsTest.setup()

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "100000",
            "date" => "2022-01-03T17:42:43.162804Z",
            "blockNumber" => "10730880",
            "blockHash" => to_string(block_2_hash),
            "epochNumber" => "621",
            "group" => to_string(group_address_1_hash)
          },
          %{
            "amount" => "200000",
            "date" => "2022-01-04T17:42:43.162804Z",
            "blockNumber" => "10748160",
            "blockHash" => to_string(block_3_hash),
            "epochNumber" => "622",
            "group" => to_string(group_address_1_hash)
          }
        ],
        "totalRewardCelo" => "300000",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z",
        "account" => to_string(validator_address_1_hash)
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorrewards",
          "validatorAddress" => to_string(validator_address_1_hash),
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

      assert response["message"] =~ "Invalid group address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with an address that doesn't exist", %{conn: conn} do
      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
        })
        |> json_response(200)

      assert response["message"] =~ "Group address does not exist"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      schema = group_rewards_schema()
      assert :ok = ExJsonSchema.Validator.validate(schema, response)
    end

    test "with valid group address", %{conn: conn} do
      {validator_address_1_hash, group_address_1_hash, block_2_hash, block_3_hash} =
        SetupValidatorAndGroupRewardsTest.setup()

      expected_result = %{
        "rewards" => [
          %{
            "amount" => "300000",
            "date" => "2022-01-03T17:42:43.162804Z",
            "blockNumber" => "10730880",
            "blockHash" => to_string(block_2_hash),
            "epochNumber" => "621",
            "validator" => to_string(validator_address_1_hash)
          },
          %{
            "amount" => "400000",
            "date" => "2022-01-04T17:42:43.162804Z",
            "blockNumber" => "10748160",
            "blockHash" => to_string(block_3_hash),
            "epochNumber" => "622",
            "validator" => to_string(validator_address_1_hash)
          }
        ],
        "totalRewardCelo" => "700000",
        "from" => "2022-01-03 00:00:00.000000Z",
        "to" => "2022-01-06 00:00:00.000000Z",
        "group" => to_string(group_address_1_hash)
      }

      response =
        conn
        |> get("/api", %{
          "module" => "reward",
          "action" => "getvalidatorgrouprewards",
          "groupAddress" => to_string(group_address_1_hash),
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
