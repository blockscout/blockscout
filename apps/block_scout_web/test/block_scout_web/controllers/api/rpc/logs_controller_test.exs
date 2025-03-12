defmodule BlockScoutWeb.API.RPC.LogsControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.API.RPC.LogsController
  alias Explorer.Chain.{Log, Transaction}

  @first_topic_hex_string_1 "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  @first_topic_hex_string_2 "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  @second_topic_hex_string_1 "0x00000000000000000000000098a9dc37d3650b5b30d6c12789b3881ee0b70c16"
  @second_topic_hex_string_2 "0x000000000000000000000000e2680fd7cdbb04e9087a647ad4d023ef6c8fb4e2"

  @third_topic_hex_string_1 "0x0000000000000000000000005079fc00f00f30000e0c8c083801cfde000008b6"

  @fourth_topic_hex_string_1 "0x8c9b7729443a4444242342b2ca385a239a5c1d76a88473e1cd2ab0c70dd1b9c7"
  @fourth_topic_hex_string_2 "0x232b688786cc0d24a11e07563c1bfa129537cec9385dc5b1fb8f86462977239b"

  defp topic(topic_hex_string) do
    {:ok, topic} = Explorer.Chain.Hash.Full.cast(topic_hex_string)
    topic
  end

  describe "getLogs" do
    test "without fromBlock, toBlock, address, and topic{x}", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs"
      }

      expected_message = "Required query parameters missing: fromBlock, toBlock, address and/or topic{x}"

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == expected_message
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "without fromBlock", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "toBlock" => "10",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      expected_message = "Required query parameters missing: fromBlock"

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == expected_message
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "without toBlock", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      expected_message = "Required query parameters missing: toBlock"

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == expected_message
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "without address and topic{x}", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "toBlock" => "10"
      }

      expected_message = "Required query parameters missing: address and/or topic{x}"

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == expected_message
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "without topic{x}_{x}_opr", %{conn: conn} do
      conditions = %{
        ["topic0", "topic1"] => "topic0_1_opr",
        ["topic0", "topic2"] => "topic0_2_opr",
        ["topic0", "topic3"] => "topic0_3_opr",
        ["topic1", "topic2"] => "topic1_2_opr",
        ["topic1", "topic3"] => "topic1_3_opr",
        ["topic2", "topic3"] => "topic2_3_opr"
      }

      for {[key1, key2], expectation} <- conditions do
        params = %{
          "module" => "logs",
          "action" => "getLogs",
          "fromBlock" => "5",
          "toBlock" => "10",
          key1 => "some topic",
          key2 => "some other topic"
        }

        expected_message = "Required query parameters missing: #{expectation}"

        assert response =
                 conn
                 |> get("/api", params)
                 |> json_response(200)

        assert response["message"] == expected_message
        assert response["status"] == "0"
        assert Map.has_key?(response, "result")
        refute response["result"]
        assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
      end
    end

    test "without multiple topic{x}_{x}_opr", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "toBlock" => "10",
        "topic0" => "some topic",
        "topic1" => "some other topic",
        "topic2" => "some extra topic",
        "topic3" => "some different topic"
      }

      expected_message =
        "Required query parameters missing: " <>
          "topic0_1_opr, topic0_2_opr, topic0_3_opr, topic1_2_opr, topic1_3_opr, topic2_3_opr"

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] == expected_message
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with invalid fromBlock", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "invalid",
        "toBlock" => "10",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid fromBlock format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with invalid toBlock", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "toBlock" => "invalid",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid toBlock format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with an invalid address hash", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "toBlock" => "10",
        "address" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid address format"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with invalid topic{x}_{x}_opr", %{conn: conn} do
      conditions = %{
        ["topic0", "topic1"] => "topic0_1_opr",
        ["topic0", "topic2"] => "topic0_2_opr",
        ["topic0", "topic3"] => "topic0_3_opr",
        ["topic1", "topic2"] => "topic1_2_opr",
        ["topic1", "topic3"] => "topic1_3_opr",
        ["topic2", "topic3"] => "topic2_3_opr"
      }

      for {[key1, key2], expectation} <- conditions do
        params = %{
          "module" => "logs",
          "action" => "getLogs",
          "fromBlock" => "5",
          "toBlock" => "10",
          key1 => "some topic",
          key2 => "some other topic",
          expectation => "invalid"
        }

        assert response =
                 conn
                 |> get("/api", params)
                 |> json_response(200)

        assert response["message"] =~ "Invalid #{expectation} format"
        assert response["status"] == "0"
        assert Map.has_key?(response, "result")
        refute response["result"]
        assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
      end
    end

    test "with an address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "5",
        "toBlock" => "10",
        "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "0"
      assert response["message"] == "No logs found"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with a valid contract address", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block()

      log =
        insert(:log,
          address: contract_address,
          transaction: transaction,
          block: block,
          block_number: transaction.block_number
        )

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "address" => "#{contract_address.hash}"
      }

      expected_result = [
        %{
          "address" => "#{contract_address.hash}",
          "topics" => get_topics(log),
          "data" => "#{log.data}",
          "blockNumber" => integer_to_hex(transaction.block_number),
          "timeStamp" => datetime_to_hex(block.timestamp),
          "gasPrice" => decimal_to_hex(transaction.gas_price.value),
          "gasUsed" => decimal_to_hex(transaction.gas_used),
          "logIndex" => integer_to_hex(log.index),
          "transactionHash" => "#{transaction.hash}",
          "transactionIndex" => integer_to_hex(transaction.index)
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "ignores logs with block below fromBlock", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)

      contract_address = insert(:contract_address)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      insert(:log,
        address: contract_address,
        transaction: transaction_block1,
        block: transaction_block1.block,
        block_number: transaction_block1.block_number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block2,
        block: transaction_block2.block,
        block_number: transaction_block2.block_number
      )

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{second_block.number}",
        "toBlock" => "#{second_block.number}",
        "address" => "#{contract_address.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)

      [found_log] = response["result"]

      assert found_log["blockNumber"] == integer_to_hex(second_block.number)
      assert found_log["transactionHash"] == "#{transaction_block2.hash}"
    end

    test "ignores logs with block above toBlock", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)

      contract_address = insert(:contract_address)

      transaction_block1 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(first_block)

      transaction_block2 =
        %Transaction{} =
        :transaction
        |> insert(to_address: contract_address)
        |> with_block(second_block)

      insert(:log,
        address: contract_address,
        transaction: transaction_block1,
        block: transaction_block1.block,
        block_number: transaction_block1.block_number
      )

      insert(:log,
        address: contract_address,
        transaction: transaction_block2,
        block: transaction_block2.block,
        block_number: transaction_block2.block_number
      )

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{first_block.number}",
        "toBlock" => "#{first_block.number}",
        "address" => "#{contract_address.hash}"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)

      [found_log] = response["result"]

      assert found_log["blockNumber"] == integer_to_hex(first_block.number)
      assert found_log["transactionHash"] == "#{transaction_block1.hash}"
    end

    test "with a valid topic{x}", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      _log2 = insert(:log, log2_details)

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "topic0" => log1.first_topic
      }

      expected_result = [
        %{
          "address" => "#{contract_address.hash}",
          "topics" => get_topics(log1),
          "data" => "#{log1.data}",
          "blockNumber" => integer_to_hex(transaction.block_number),
          "timeStamp" => datetime_to_hex(block.timestamp),
          "gasPrice" => decimal_to_hex(transaction.gas_price.value),
          "gasUsed" => decimal_to_hex(transaction.gas_used),
          "logIndex" => integer_to_hex(log1.index),
          "transactionHash" => "#{transaction.hash}",
          "transactionIndex" => integer_to_hex(transaction.index)
        }
      ]

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with a topic{x} AND another", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      _log2 = insert(:log, log2_details)

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "topic0" => log1.first_topic,
        "topic1" => log1.second_topic,
        "topic0_1_opr" => "and"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert [found_log] = response["result"]
      assert found_log["logIndex"] == integer_to_hex(log1.index)
      assert found_log["topics"] == get_topics(log1)
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with a topic{x} OR another", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_2),
        second_topic: topic(@second_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "topic0" => log1.first_topic,
        "topic1" => log2.second_topic,
        "topic0_1_opr" => "or"
      }

      assert %{"result" => result} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(result) == 2
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end

    test "with all available 'topic{x}'s and 'topic{x}_{x}_opr's", %{conn: conn} do
      contract_address = insert(:contract_address)

      transaction =
        %Transaction{block: block} =
        :transaction
        |> insert()
        |> with_block()

      log1_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        fourth_topic: topic(@fourth_topic_hex_string_1)
      ]

      log2_details = [
        address: contract_address,
        transaction: transaction,
        block: block,
        block_number: block.number,
        first_topic: topic(@first_topic_hex_string_1),
        second_topic: topic(@second_topic_hex_string_1),
        third_topic: topic(@third_topic_hex_string_1),
        fourth_topic: topic(@fourth_topic_hex_string_2)
      ]

      log1 = insert(:log, log1_details)
      log2 = insert(:log, log2_details)

      params = %{
        "module" => "logs",
        "action" => "getLogs",
        "fromBlock" => "#{block.number}",
        "toBlock" => "#{block.number}",
        "topic0" => log1.first_topic,
        "topic1" => log1.second_topic,
        "topic2" => log1.third_topic,
        "topic3" => log2.fourth_topic,
        "topic0_1_opr" => "and",
        "topic0_2_opr" => "and",
        "topic0_3_opr" => "or",
        "topic1_2_opr" => "and",
        "topic1_3_opr" => "or",
        "topic2_3_opr" => "or"
      }

      assert %{"result" => result} =
               response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert length(result) == 2
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(getlogs_schema(), response)
    end
  end

  describe "fetch_required_params/1" do
    test "without any required params" do
      params = %{}

      {_, {:error, missing_params}} = LogsController.fetch_required_params(params)

      assert missing_params == ["fromBlock", "toBlock", "address and/or topic{x}"]
    end

    test "without fromBlock" do
      params = %{
        "toBlock" => "5",
        "address" => "some address"
      }

      {_, {:error, [missing_param]}} = LogsController.fetch_required_params(params)

      assert missing_param == "fromBlock"
    end

    test "without toBlock" do
      params = %{
        "fromBlock" => "5",
        "address" => "some address"
      }

      {_, {:error, [missing_param]}} = LogsController.fetch_required_params(params)

      assert missing_param == "toBlock"
    end

    test "without fromBlock or toBlock" do
      params = %{
        "address" => "some address"
      }

      {_, {:error, missing_params}} = LogsController.fetch_required_params(params)

      assert missing_params == ["fromBlock", "toBlock"]
    end

    test "without address or topic{x}" do
      params = %{
        "toBlock" => "5",
        "fromBlock" => "5"
      }

      {_, {:error, [missing_param]}} = LogsController.fetch_required_params(params)

      assert missing_param == "address and/or topic{x}"
    end

    test "with address" do
      params = %{
        "fromBlock" => "5",
        "toBlock" => "5",
        "address" => "some address"
      }

      {_, {:ok, fetched_params}} = LogsController.fetch_required_params(params)

      assert fetched_params == params
    end

    test "with topic{x}" do
      for topic <- ["topic0", "topic1", "topic2", "topic3"] do
        params = %{
          "fromBlock" => "5",
          "toBlock" => "5",
          topic => "some topic"
        }

        {_, {:ok, fetched_params}} = LogsController.fetch_required_params(params)

        assert fetched_params == params
      end
    end

    test "with address and topic{x}" do
      params = %{
        "fromBlock" => "5",
        "toBlock" => "5",
        "address" => "some address",
        "topic0" => "some topic"
      }

      {_, {:ok, fetched_params}} = LogsController.fetch_required_params(params)

      assert fetched_params == params
    end
  end

  describe "to_valid_format/1" do
    test "with invalid fromBlock" do
      params = %{"fromBlock" => "invalid"}

      assert {_, {:error, "fromBlock"}} = LogsController.to_valid_format(params)
    end

    test "with invalid toBlock" do
      params = %{
        "fromBlock" => "5",
        "toBlock" => "invalid"
      }

      assert {_, {:error, "toBlock"}} = LogsController.to_valid_format(params)
    end

    test "with invalid address" do
      params = %{
        "fromBlock" => "5",
        "toBlock" => "10",
        "address" => "invalid"
      }

      assert {_, {:error, "address"}} = LogsController.to_valid_format(params)
    end

    test "address_hash returns as nil when missing" do
      params = %{
        "fromBlock" => "5",
        "toBlock" => "10"
      }

      assert {_, {:ok, validated_params}} = LogsController.to_valid_format(params)
      refute validated_params.address_hash
    end

    test "fromBlock and toBlock support use of 'latest'" do
      params = %{
        "fromBlock" => "latest",
        "toBlock" => "latest"
      }

      # Without any blocks in the db we want to return {:error, :not_found}
      assert {_, {:error, :not_found}} = LogsController.to_valid_format(params)

      # We insert a block, try again, and assert 'latest' points to the latest
      # block number.
      insert(:block)
      {:ok, max_consensus_block_number} = Explorer.Chain.max_consensus_block_number()

      assert {_, {:ok, validated_params}} = LogsController.to_valid_format(params)
      assert validated_params.from_block == max_consensus_block_number
      assert validated_params.to_block == max_consensus_block_number
    end
  end

  defp get_topics(%Log{
         first_topic: first_topic,
         second_topic: second_topic,
         third_topic: third_topic,
         fourth_topic: fourth_topic
       }) do
    [
      first_topic && Explorer.Chain.Hash.to_string(first_topic),
      second_topic && Explorer.Chain.Hash.to_string(second_topic),
      third_topic && Explorer.Chain.Hash.to_string(third_topic),
      fourth_topic && Explorer.Chain.Hash.to_string(fourth_topic)
    ]
  end

  defp integer_to_hex(integer), do: "0x" <> String.downcase(Integer.to_string(integer, 16))

  defp decimal_to_hex(decimal) do
    decimal
    |> Decimal.to_integer()
    |> integer_to_hex()
  end

  defp datetime_to_hex(datetime) do
    datetime
    |> DateTime.to_unix()
    |> integer_to_hex()
  end

  defp getlogs_schema do
    ExJsonSchema.Schema.resolve(%{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "result" => %{
          "type" => ["array", "null"],
          "items" => %{
            "type" => "object",
            "properties" => %{
              "address" => %{"type" => "string"},
              "topics" => %{"type" => "array", "items" => %{"type" => ["string", "null"]}},
              "data" => %{"type" => "string"},
              "blockNumber" => %{"type" => "string"},
              "timeStamp" => %{"type" => "string"},
              "gasPrice" => %{"type" => "string"},
              "gasUsed" => %{"type" => "string"},
              "logIndex" => %{"type" => "string"},
              "transactionHash" => %{"type" => "string"},
              "transactionIndex" => %{"type" => "string"}
            }
          }
        }
      }
    })
  end
end
