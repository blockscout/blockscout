defmodule BlockScoutWeb.API.V2.BlockControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction, Withdrawal}
  alias Explorer.Chain.Beacon.Deposit, as: BeaconDeposit

  setup do
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Blocks.child_id())
    Supervisor.terminate_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())
    Supervisor.restart_child(Explorer.Supervisor, Explorer.Chain.Cache.Uncles.child_id())

    Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts,
      contracts: %{
        "addresses" => %{
          "Accounts" => [],
          "Election" => [],
          "EpochRewards" => [],
          "FeeHandler" => [],
          "GasPriceMinimum" => [],
          "GoldToken" => [],
          "Governance" => [],
          "LockedGold" => [],
          "Reserve" => [],
          "StableToken" => [],
          "Validators" => []
        }
      }
    )

    on_exit(fn ->
      Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, contracts: %{})
    end)

    :ok
  end

  describe "/blocks" do
    test "empty lists", %{conn: conn} do
      request = get(conn, "/api/v2/blocks")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "uncle"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "reorg"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks", %{"type" => "block"})
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get block", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks")

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(block, Enum.at(response["items"], 0))
    end

    test "type=block returns only consensus blocks", %{conn: conn} do
      blocks =
        4
        |> insert_list(:block)
        |> Enum.reverse()

      for index <- 0..3 do
        uncle = insert(:block, consensus: false)
        insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
      end

      2
      |> insert_list(:block, consensus: false)

      request = get(conn, "/api/v2/blocks", %{"type" => "block"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(blocks, index), Enum.at(response["items"], index))
      end
    end

    test "type=block can paginate", %{conn: conn} do
      blocks =
        51
        |> insert_list(:block)

      filter = %{"type" => "block"}

      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, blocks)
    end

    test "type=reorg returns only non consensus blocks", %{conn: conn} do
      blocks =
        5
        |> insert_list(:block)

      for index <- 0..3 do
        uncle = insert(:block, consensus: false)
        insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
      end

      reorgs =
        4
        |> insert_list(:block, consensus: false)
        |> Enum.reverse()

      Enum.each(reorgs, fn b -> insert(:block, number: b.number, consensus: true) end)

      request = get(conn, "/api/v2/blocks", %{"type" => "reorg"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(reorgs, index), Enum.at(response["items"], index))
      end
    end

    test "type=reorg can paginate", %{conn: conn} do
      reorgs =
        51
        |> insert_list(:block, consensus: false)

      Enum.each(reorgs, fn b -> insert(:block, number: b.number, consensus: true) end)

      filter = %{"type" => "reorg"}
      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, reorgs)
    end

    test "type=uncle returns only uncle blocks", %{conn: conn} do
      blocks =
        4
        |> insert_list(:block)
        |> Enum.reverse()

      uncles =
        for index <- 0..3 do
          uncle = insert(:block, consensus: false)
          insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
          uncle
        end
        |> Enum.reverse()

      4
      |> insert_list(:block, consensus: false)

      request = get(conn, "/api/v2/blocks", %{"type" => "uncle"})

      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 4
      assert response["next_page_params"] == nil

      for index <- 0..3 do
        compare_item(Enum.at(uncles, index), Enum.at(response["items"], index))
      end
    end

    test "type=uncle can paginate", %{conn: conn} do
      blocks =
        51
        |> insert_list(:block)

      uncles =
        for index <- 0..50 do
          uncle = insert(:block, consensus: false)
          insert(:block_second_degree_relation, uncle_hash: uncle.hash, nephew: Enum.at(blocks, index))
          uncle
        end

      filter = %{"type" => "uncle"}
      request = get(conn, "/api/v2/blocks", filter)
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks", Map.merge(response["next_page_params"], filter))

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, uncles)
    end
  end

  describe "/blocks/{block_hash_or_number}" do
    test "return 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_2, 422)
    end

    test "return 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "get 'Block lost consensus' message", %{conn: conn} do
      block = insert(:block, consensus: false)
      hash = to_string(block.hash)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}")
      assert %{"message" => "Block lost consensus", "hash" => ^hash} = json_response(request_1, 404)
    end

    test "get the same blocks by hash and number", %{conn: conn} do
      block = insert(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}")
      assert response_1 = json_response(request_1, 200)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}")
      assert response_2 = json_response(request_2, 200)

      assert response_2 == response_1
      compare_item(block, response_2)
    end

    test "includes is_pending_update field in response", %{conn: conn} do
      block_refetch_needed = insert(:block, refetch_needed: true)
      block_no_refetch = insert(:block, refetch_needed: false)

      request_1 = get(conn, "/api/v2/blocks/#{block_refetch_needed.hash}")
      assert response_1 = json_response(request_1, 200)
      assert response_1["is_pending_update"] == true

      request_2 = get(conn, "/api/v2/blocks/#{block_no_refetch.hash}")
      assert response_2 = json_response(request_2, 200)
      assert response_2["is_pending_update"] == false
    end

    test "includes is_pending_update field in block lists", %{conn: conn} do
      block_refetch_needed = insert(:block, refetch_needed: true)
      block_no_refetch = insert(:block, refetch_needed: false)

      request = get(conn, "/api/v2/blocks")
      assert response = json_response(request, 200)

      # Find the blocks in the response
      refetch_block_response =
        Enum.find(response["items"], fn item -> item["hash"] == to_string(block_refetch_needed.hash) end)

      no_refetch_block_response =
        Enum.find(response["items"], fn item -> item["hash"] == to_string(block_no_refetch.hash) end)

      assert refetch_block_response["is_pending_update"] == true
      assert no_refetch_block_response["is_pending_update"] == false
    end

    if @chain_type == :celo do
      test "get block with Celo base fee information when chain type is celo", %{conn: conn} do
        # Store original configuration
        original_celo_config = Application.get_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts)

        # Set up Celo core contracts configuration for base fee
        fee_handler_address = insert(:address)
        governance_address = insert(:address)
        celo_token_address = insert(:address)

        celo_config = [
          contracts: %{
            "addresses" => %{
              "FeeHandler" => [
                %{
                  "address" => to_string(fee_handler_address.hash),
                  "updated_at_block_number" => 0
                }
              ],
              "Governance" => [
                %{
                  "address" => to_string(governance_address.hash),
                  "updated_at_block_number" => 0
                }
              ],
              "GoldToken" => [
                %{
                  "address" => to_string(celo_token_address.hash),
                  "updated_at_block_number" => 0
                }
              ]
            },
            "events" => %{
              "FeeHandler" => %{
                "FeeBeneficiarySet" => [
                  %{
                    "address_hash" => to_string(insert(:address).hash),
                    "updated_at_block_number" => 0
                  }
                ],
                "BurnFractionSet" => [
                  %{
                    "value" => "500000000000000000000000",
                    "updated_at_block_number" => 0
                  }
                ]
              }
            }
          }
        ]

        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, celo_config)

        # Create a CELO token for the response
        insert(:token,
          contract_address_hash: celo_token_address.hash,
          contract_address: celo_token_address,
          symbol: "CELO",
          name: "Celo",
          type: "ERC-20"
        )

        # Create a block with base fee and transactions
        block =
          insert(:block,
            # 1 gwei
            base_fee_per_gas: 1_000_000_000
          )

        # Create transactions for the block to calculate burnt fees
        for index <- 0..2 do
          insert(:transaction,
            block_hash: block.hash,
            block_number: block.number,
            # 2 gwei
            gas_price: 2_000_000_000,
            gas_used: 21_000,
            max_fee_per_gas: 2_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            cumulative_gas_used: 21_000,
            index: index
          )
        end

        # Make the request
        request = get(conn, "/api/v2/blocks/#{block.hash}")
        assert response = json_response(request, 200)

        # Verify basic block information
        compare_item(block, response)

        # Verify Celo-specific information is present
        assert Map.has_key?(response, "celo")
        celo_info = response["celo"]

        # Verify epoch information
        assert Map.has_key?(celo_info, "epoch_number")
        assert Map.has_key?(celo_info, "is_epoch_block")
        assert celo_info["is_epoch_block"] == false

        # Verify base fee information is present
        assert Map.has_key?(celo_info, "base_fee")
        assert base_fee_info = celo_info["base_fee"]

        # Verify base fee structure
        assert Map.has_key?(base_fee_info, "recipient")
        assert Map.has_key?(base_fee_info, "amount")
        assert Map.has_key?(base_fee_info, "token")
        assert Map.has_key?(base_fee_info, "breakdown")

        # Verify token information
        token_info = base_fee_info["token"]
        assert token_info["symbol"] == "CELO"
        assert token_info["name"] == "Celo"

        # Verify recipient information
        recipient = base_fee_info["recipient"]
        assert Map.has_key?(recipient, "hash")

        # Verify breakdown structure
        breakdown = base_fee_info["breakdown"]
        assert is_list(breakdown)

        # Restore original configuration
        on_exit(fn ->
          Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, original_celo_config)
        end)
      end

      test "get block with Celo governance base fee when fee handler is not available", %{conn: conn} do
        # Store original configuration
        original_celo_config = Application.get_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts)

        # Set up Celo core contracts configuration with only governance (no fee handler)
        governance_address = insert(:address)
        celo_token_address = insert(:address)

        celo_config = [
          contracts: %{
            "addresses" => %{
              "Governance" => [
                %{
                  "address" => to_string(governance_address.hash),
                  "updated_at_block_number" => 0
                }
              ],
              "GoldToken" => [
                %{
                  "address" => to_string(celo_token_address.hash),
                  "updated_at_block_number" => 0
                }
              ]
            }
          }
        ]

        Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, celo_config)

        # Create a CELO token for the response
        insert(:token,
          contract_address_hash: celo_token_address.hash,
          contract_address: celo_token_address,
          symbol: "CELO",
          name: "Celo",
          type: "ERC-20"
        )

        # Create a block with base fee and transactions
        block =
          insert(:block,
            # 1 gwei
            base_fee_per_gas: 1_000_000_000
          )

        # Create transactions for the block to calculate burnt fees
        for index <- 0..2 do
          insert(:transaction,
            block_hash: block.hash,
            block_number: block.number,
            # 2 gwei
            gas_price: 2_000_000_000,
            gas_used: 21_000,
            max_fee_per_gas: 2_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            cumulative_gas_used: 21_000,
            index: index
          )
        end

        # Make the request
        request = get(conn, "/api/v2/blocks/#{block.hash}")
        assert response = json_response(request, 200)

        # Verify basic block information
        compare_item(block, response)

        # Verify Celo-specific information is present
        assert Map.has_key?(response, "celo")
        celo_info = response["celo"]

        # Verify epoch information
        assert Map.has_key?(celo_info, "epoch_number")
        assert Map.has_key?(celo_info, "is_epoch_block")

        # Verify base fee information is present (may be nil if governance fallback doesn't work)
        assert Map.has_key?(celo_info, "base_fee")
        assert base_fee_info = celo_info["base_fee"]

        # Verify base fee structure for governance case
        assert Map.has_key?(base_fee_info, "recipient")
        assert Map.has_key?(base_fee_info, "amount")
        assert Map.has_key?(base_fee_info, "token")
        assert Map.has_key?(base_fee_info, "breakdown")

        # For governance case, breakdown should be empty
        breakdown = base_fee_info["breakdown"]
        assert is_list(breakdown)
        assert Enum.empty?(breakdown)

        # Restore original configuration
        on_exit(fn ->
          Application.put_env(:explorer, Explorer.Chain.Cache.CeloCoreContracts, original_celo_config)
        end)
      end
    end
  end

  describe "/blocks/{block_hash_or_number}/transactions" do
    test "return 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123/transactions")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe/transactions")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_2, 422)
    end

    test "return 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "get empty list", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get relevant transaction", %{conn: conn} do
      10
      |> insert_list(:transaction)
      |> with_block()

      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 1
      assert response["next_page_params"] == nil
      compare_item(transaction, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response_1 = json_response(request, 200)
      assert response_1 == response
    end

    test "get transactions with working next_page_params", %{conn: conn} do
      2
      |> insert_list(:transaction)
      |> with_block()

      block = insert(:block)

      transactions =
        51
        |> insert_list(:transaction)
        |> with_block(block)
        |> Enum.reverse()

      request = get(conn, "/api/v2/blocks/#{block.number}/transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks/#{block.number}/transactions", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, transactions)

      request_1 = get(conn, "/api/v2/blocks/#{block.hash}/transactions")
      assert response_1 = json_response(request_1, 200)

      assert response_1 == response

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/transactions", response_1["next_page_params"])
      assert response_2 = json_response(request_2, 200)
      assert response_2 == response_2nd_page
    end
  end

  describe "/blocks/{block_hash_or_number}/withdrawals" do
    test "return 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123/withdrawals")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe/withdrawals")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_2, 422)
    end

    test "return 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}/withdrawals")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/withdrawals")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "get empty list", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks/#{block.number}/withdrawals")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil

      request = get(conn, "/api/v2/blocks/#{block.hash}/withdrawals")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get withdrawals", %{conn: conn} do
      block = insert(:block, withdrawals: insert_list(3, :withdrawal))

      [withdrawal | _] = Enum.reverse(block.withdrawals)

      request = get(conn, "/api/v2/blocks/#{block.number}/withdrawals")
      assert response = json_response(request, 200)
      assert Enum.count(response["items"]) == 3
      assert response["next_page_params"] == nil
      compare_item(withdrawal, Enum.at(response["items"], 0))

      request = get(conn, "/api/v2/blocks/#{block.hash}/withdrawals")
      assert response_1 = json_response(request, 200)
      assert response_1 == response
    end

    test "get withdrawals with working next_page_params", %{conn: conn} do
      block = insert(:block, withdrawals: insert_list(51, :withdrawal))

      request = get(conn, "/api/v2/blocks/#{block.number}/withdrawals")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks/#{block.number}/withdrawals", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, block.withdrawals)

      request_1 = get(conn, "/api/v2/blocks/#{block.hash}/withdrawals")
      assert response_1 = json_response(request_1, 200)

      assert response_1 == response

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/withdrawals", response_1["next_page_params"])
      assert response_2 = json_response(request_2, 200)
      assert response_2 == response_2nd_page
    end
  end

  describe "/blocks/{block_hash_or_number}/internal-transactions" do
    test "returns 422 on invalid parameter", %{conn: conn} do
      request_1 = get(conn, "/api/v2/blocks/0x123123/internal-transactions")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_1, 422)

      request_2 = get(conn, "/api/v2/blocks/123qwe/internal-transactions")

      assert %{
               "errors" => [
                 %{
                   "detail" =>
                     "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid integer. Got: string",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                   "source" => %{"pointer" => "/block_hash_or_number_param"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(request_2, 422)
    end

    test "returns 404 on non existing block", %{conn: conn} do
      block = build(:block)

      request_1 = get(conn, "/api/v2/blocks/#{block.number}/internal-transactions")
      assert %{"message" => "Not found"} = json_response(request_1, 404)

      request_2 = get(conn, "/api/v2/blocks/#{block.hash}/internal-transactions")
      assert %{"message" => "Not found"} = json_response(request_2, 404)
    end

    test "returns empty list", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks/#{block.hash}/internal-transactions")
      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)

      request = get(conn, "/api/v2/blocks/#{block.number}/internal-transactions")
      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)
    end

    test "can paginate internal transactions", %{conn: conn} do
      block = insert(:block)

      request = get(conn, "/api/v2/blocks/#{block.hash}/internal-transactions")
      assert %{"items" => [], "next_page_params" => nil} = json_response(request, 200)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      internal_transactions =
        51..1
        |> Enum.map(fn index ->
          transaction =
            :transaction
            |> insert()
            |> with_block(block)

          insert(:internal_transaction,
            transaction: transaction,
            index: index,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            block_hash: transaction.block_hash,
            block_index: index
          )
        end)

      request = get(conn, "/api/v2/blocks/#{block.hash}/internal-transactions")
      assert response = json_response(request, 200)

      request_2nd_page = get(conn, "/api/v2/blocks/#{block.hash}/internal-transactions", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(response, response_2nd_page, internal_transactions)
    end
  end

  if @chain_type == :ethereum do
    describe "blocks/{block_hash_or_number}/beacon/deposits" do
      test "get 404 on non-existing block", %{conn: conn} do
        block = build(:block)

        request = get(conn, "/api/v2/blocks/#{block.hash}/beacon/deposits")
        json_response(request, 404)
      end

      test "get 422 on invalid block", %{conn: conn} do
        request_1 = get(conn, "/api/v2/blocks/0x123123/beacon/deposits")

        assert %{
                 "errors" => [
                   %{
                     "detail" =>
                       "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   },
                   %{
                     "detail" => "Invalid integer. Got: string",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   },
                   %{
                     "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   }
                 ]
               } = json_response(request_1, 422)

        request_2 = get(conn, "/api/v2/blocks/123qwe/beacon/deposits")

        assert %{
                 "errors" => [
                   %{
                     "detail" =>
                       "Failed to cast value using any of: Schema(title: \"FullHash\", type: :string), Schema(type: :integer)",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   },
                   %{
                     "detail" => "Invalid integer. Got: string",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   },
                   %{
                     "detail" => "Invalid format. Expected ~r/^0x([A-Fa-f0-9]{64})$/",
                     "source" => %{"pointer" => "/block_hash_or_number_param"},
                     "title" => "Invalid value"
                   }
                 ]
               } = json_response(request_2, 422)
      end

      test "get deposits", %{conn: conn} do
        block = insert(:block)

        deposits = insert_list(51, :beacon_deposit, block: block)

        insert(:beacon_deposit)

        request = get(conn, "/api/v2/blocks/#{block.hash}/beacon/deposits")
        assert response = json_response(request, 200)

        request_2nd_page = get(conn, "/api/v2/blocks/#{block.hash}/beacon/deposits", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(response, response_2nd_page, deposits)
      end
    end
  end

  defp compare_item(%Block{} = block, json) do
    assert to_string(block.hash) == json["hash"]
    assert block.number == json["height"]
  end

  defp compare_item(%Transaction{} = transaction, json) do
    assert to_string(transaction.hash) == json["hash"]
    assert transaction.block_number == json["block_number"]
    assert to_string(transaction.value.value) == json["value"]
    assert Address.checksum(transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%Withdrawal{} = withdrawal, json) do
    assert withdrawal.index == json["index"]
  end

  defp compare_item(%InternalTransaction{} = internal_transaction, json) do
    assert internal_transaction.block_number == json["block_number"]
    assert to_string(internal_transaction.gas) == json["gas_limit"]
    assert internal_transaction.index == json["index"]
    assert to_string(internal_transaction.transaction_hash) == json["transaction_hash"]
    assert Address.checksum(internal_transaction.from_address_hash) == json["from"]["hash"]
    assert Address.checksum(internal_transaction.to_address_hash) == json["to"]["hash"]
  end

  defp compare_item(%BeaconDeposit{} = deposit, json) do
    index = deposit.index
    transaction_hash = to_string(deposit.transaction_hash)
    block_hash = to_string(deposit.block_hash)
    block_number = deposit.block_number
    pubkey = to_string(deposit.pubkey)
    withdrawal_credentials = to_string(deposit.withdrawal_credentials)
    signature = to_string(deposit.signature)
    from_address_hash = Address.checksum(deposit.from_address_hash)

    if deposit.withdrawal_address_hash do
      withdrawal_address_hash = Address.checksum(deposit.withdrawal_address_hash)

      assert %{
               "index" => ^index,
               "transaction_hash" => ^transaction_hash,
               "block_hash" => ^block_hash,
               "block_number" => ^block_number,
               "pubkey" => ^pubkey,
               "withdrawal_credentials" => ^withdrawal_credentials,
               "withdrawal_address" => %{"hash" => ^withdrawal_address_hash},
               "signature" => ^signature,
               "from_address" => %{"hash" => ^from_address_hash}
             } = json
    else
      assert %{
               "index" => ^index,
               "transaction_hash" => ^transaction_hash,
               "block_hash" => ^block_hash,
               "block_number" => ^block_number,
               "pubkey" => ^pubkey,
               "withdrawal_credentials" => ^withdrawal_credentials,
               "withdrawal_address" => nil,
               "signature" => ^signature,
               "from_address" => %{"hash" => ^from_address_hash}
             } = json
    end
  end

  defp check_paginated_response(first_page_resp, second_page_resp, list) do
    assert Enum.count(first_page_resp["items"]) == 50
    assert first_page_resp["next_page_params"] != nil
    compare_item(Enum.at(list, 50), Enum.at(first_page_resp["items"], 0))
    compare_item(Enum.at(list, 1), Enum.at(first_page_resp["items"], 49))

    assert Enum.count(second_page_resp["items"]) == 1
    assert second_page_resp["next_page_params"] == nil
    compare_item(Enum.at(list, 0), Enum.at(second_page_resp["items"], 0))
  end
end
