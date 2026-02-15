defmodule BlockScoutWeb.API.V2.AdvancedFilterControllerTest do
  use BlockScoutWeb.ConnCase

  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.{AdvancedFilter, Data, Hash}
  alias Explorer.{Factory, TestHelper}

  describe "/advanced_filters" do
    test "get token-transfers with ok reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction = insert(:transaction) |> with_block()

      insert(:token_transfer, transaction: transaction)

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"

      assert response ==
               conn
               |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})
               |> json_response(200)
    end

    test "get smart-contract with scam reputation", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, true)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction = insert(:transaction) |> with_block()

      tt = insert(:token_transfer, transaction: transaction)
      insert(:scam_badge_to_address, address_hash: tt.token_contract_address_hash)

      request =
        conn
        |> put_req_cookie("show_scam_tokens", "true")
        |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "scam"

      request =
        conn |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})

      response = json_response(request, 200)

      assert response["items"] == []
    end

    test "get token-transfers with ok reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction = insert(:transaction) |> with_block()

      insert(:token_transfer, transaction: transaction)

      request =
        conn |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "get token-transfers with scam reputation with hide_scam_addresses=false", %{conn: conn} do
      init_value = Application.get_env(:block_scout_web, :hide_scam_addresses)
      Application.put_env(:block_scout_web, :hide_scam_addresses, false)
      on_exit(fn -> Application.put_env(:block_scout_web, :hide_scam_addresses, init_value) end)

      transaction = insert(:transaction) |> with_block()
      tt = insert(:token_transfer, transaction: transaction)
      insert(:scam_badge_to_address, address_hash: tt.token_contract_address_hash)

      request =
        conn |> get("/api/v2/advanced-filters", %{"transaction_types" => "ERC-20,ERC-404,ERC-721,ERC-1155,ERC-7984"})

      response = json_response(request, 200)

      assert List.first(response["items"])["token"]["reputation"] == "ok"
    end

    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get and paginate advanced filter (transactions split between pages)", %{conn: conn} do
      first_transaction = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_transaction)

      for i <- 1..3 do
        insert(:internal_transaction,
          transaction: first_transaction,
          block_hash: first_transaction.block_hash,
          block_number: first_transaction.block_number,
          transaction_index: first_transaction.index,
          index: i
        )
      end

      insert_list(51, :transaction) |> with_block()

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "get and paginate advanced filter (token transfers split between pages)", %{conn: conn} do
      first_transaction = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_transaction)

      for i <- 1..3 do
        insert(:internal_transaction,
          transaction: first_transaction,
          block_hash: first_transaction.block_hash,
          block_number: first_transaction.block_number,
          transaction_index: first_transaction.index,
          index: i
        )
      end

      second_transaction = :transaction |> insert() |> with_block()
      insert_list(50, :token_transfer, transaction: second_transaction, block_number: second_transaction.block_number)

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "get and paginate advanced filter (batch token transfers split between pages)", %{conn: conn} do
      first_transaction = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_transaction)

      for i <- 1..3 do
        insert(:internal_transaction,
          transaction: first_transaction,
          block_hash: first_transaction.block_hash,
          block_number: first_transaction.block_number,
          transaction_index: first_transaction.index,
          index: i
        )
      end

      second_transaction = :transaction |> insert() |> with_block()

      insert_list(5, :token_transfer,
        transaction: second_transaction,
        block_number: second_transaction.block_number,
        token_type: "ERC-1155",
        token_ids: 0..10 |> Enum.to_list(),
        amounts: 10..20 |> Enum.to_list()
      )

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "get and paginate advanced filter (internal transactions split between pages)", %{conn: conn} do
      first_transaction = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_transaction)

      for i <- 1..3 do
        insert(:internal_transaction,
          transaction: first_transaction,
          block_hash: first_transaction.block_hash,
          block_number: first_transaction.block_number,
          transaction_index: first_transaction.index,
          index: i
        )
      end

      second_transaction = :transaction |> insert() |> with_block()

      for i <- 1..50 do
        insert(:internal_transaction,
          transaction: second_transaction,
          block_hash: second_transaction.block_hash,
          block_number: second_transaction.block_number,
          transaction_index: second_transaction.index,
          index: i
        )
      end

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "filter by transaction_type", %{conn: conn} do
      30 |> insert_list(:transaction) |> with_block()

      transaction = insert(:transaction) |> with_block()

      for token_type <- ~w(ERC-20 ERC-404 ERC-721 ERC-1155 ERC-7984),
          token = insert(:token, type: token_type),
          _ <- 0..4 do
        insert(:token_transfer,
          transaction: transaction,
          token_type: token_type,
          token: token,
          token_contract_address_hash: token.contract_address_hash,
          token_contract_address: token.contract_address
        )
      end

      transaction = :transaction |> insert() |> with_block()

      for i <- 1..30 do
        insert(:internal_transaction,
          transaction: transaction,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i
        )
      end

      for transaction_type_filter_string <-
            ~w(COIN_TRANSFER COIN_TRANSFER,ERC-404 ERC-721,ERC-1155 ERC-20,COIN_TRANSFER,ERC-1155 ERC-7984) do
        transaction_type_filter = transaction_type_filter_string |> String.split(",")
        request = get(conn, "/api/v2/advanced-filters", %{"transaction_types" => transaction_type_filter_string})
        assert response = json_response(request, 200)

        assert Enum.all?(response["items"], fn item -> String.upcase(item["type"]) in transaction_type_filter end)

        if response["next_page_params"] do
          request_2nd_page =
            get(
              conn,
              "/api/v2/advanced-filters",
              Map.merge(%{"transaction_types" => transaction_type_filter_string}, response["next_page_params"])
            )

          assert response_2nd_page = json_response(request_2nd_page, 200)

          assert Enum.all?(response_2nd_page["items"], fn item ->
                   String.upcase(item["type"]) in transaction_type_filter
                 end)

          check_paginated_response(
            AdvancedFilter.list(transaction_types: transaction_type_filter),
            response["items"],
            response_2nd_page["items"]
          )
        end
      end
    end

    test "filter by COIN_TRANSFER transaction_type", %{conn: conn} do
      for i <- 1..50 do
        value = if i < 20, do: 0, else: 1
        transaction = insert(:transaction, value: value) |> with_block()

        insert(:internal_transaction,
          transaction: transaction,
          value: value,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i
        )
      end

      request = get(conn, "/api/v2/advanced-filters", %{"transaction_types" => "coin_transfer"})
      assert response = json_response(request, 200)

      assert Enum.all?(response["items"], fn item ->
               String.upcase(item["type"]) == "COIN_TRANSFER" and item["value"] > 0
             end)

      request_2nd_page =
        get(
          conn,
          "/api/v2/advanced-filters",
          Map.merge(%{"transaction_types" => "coin_transfer"}, response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response_2nd_page["items"]) == 12

      assert Enum.all?(response_2nd_page["items"], fn item ->
               String.upcase(item["type"]) == "COIN_TRANSFER" and item["value"] > 0
             end)

      check_paginated_response(
        AdvancedFilter.list(transaction_types: ["COIN_TRANSFER"]),
        response["items"],
        response_2nd_page["items"]
      )
    end

    test "filter by CONTRACT_INTERACTION transaction_type", %{conn: conn} do
      contract_address =
        insert(:address, contract_code: Factory.contract_code_info().bytecode)

      for i <- 1..50 do
        if i < 20 do
          transaction = insert(:transaction) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i
          )
        else
          transaction =
            insert(:transaction, to_address_hash: contract_address.hash, to_address: contract_address) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            to_address_hash: contract_address.hash,
            to_address: contract_address,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i
          )
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"transaction_types" => "contract_interaction"})
      assert response = json_response(request, 200)

      assert Enum.all?(response["items"], fn item ->
               item["to"]["hash"] == to_string(contract_address)
             end)

      request_2nd_page =
        get(
          conn,
          "/api/v2/advanced-filters",
          Map.merge(%{"transaction_types" => "contract_interaction"}, response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response_2nd_page["items"]) == 12

      assert Enum.all?(response_2nd_page["items"], fn item ->
               item["to"]["hash"] == to_string(contract_address)
             end)

      check_paginated_response(
        AdvancedFilter.list(transaction_types: ["CONTRACT_INTERACTION"]),
        response["items"],
        response_2nd_page["items"]
      )
    end

    test "filter by CONTRACT_CREATION transaction_type", %{conn: conn} do
      for i <- 1..62 do
        address = insert(:address, contract_code: Factory.contract_code_info().bytecode)

        if i < 20 do
          transaction = insert(:transaction) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            created_contract_address: address,
            created_contract_address_hash: address.hash,
            to_address_hash: nil,
            to_address: nil,
            index: i
          )
        else
          transaction =
            insert(:transaction,
              created_contract_address: address,
              created_contract_address_hash: address.hash,
              to_address_hash: nil,
              to_address: nil
            )
            |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i
          )
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"transaction_types" => "contract_creation"})
      assert response = json_response(request, 200)

      assert Enum.all?(response["items"], fn item ->
               is_nil(item["to"]) and not is_nil(item["created_contract"])
             end)

      request_2nd_page =
        get(
          conn,
          "/api/v2/advanced-filters",
          Map.merge(%{"transaction_types" => "contract_creation"}, response["next_page_params"])
        )

      assert response_2nd_page = json_response(request_2nd_page, 200)

      assert Enum.count(response_2nd_page["items"]) == 12

      assert Enum.all?(response_2nd_page["items"], fn item ->
               is_nil(item["to"]) and not is_nil(item["created_contract"])
             end)

      check_paginated_response(
        AdvancedFilter.list(transaction_types: ["CONTRACT_CREATION"]),
        response["items"],
        response_2nd_page["items"]
      )
    end

    test "filter by methods", %{conn: conn} do
      EthereumJSONRPC.Mox
      |> TestHelper.mock_generic_proxy_requests()

      transaction = :transaction |> insert() |> with_block()

      smart_contract = build(:smart_contract)

      abi =
        %{
          "constant" => false,
          "inputs" => [%{"name" => "x", "type" => "uint64"}, %{"name" => "y", "type" => "address"}],
          "name" => "getAccess",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }

      [parsed_method] = ABI.parse_specification([abi])

      insert(:contract_method,
        abi: abi,
        identifier: parsed_method.method_id
      )

      contract_address =
        insert(:address,
          hash: address_hash(),
          verified: true,
          contract_code: Factory.contract_code_info().bytecode,
          smart_contract: smart_contract
        )

      method_id1_string = "0xa9059cbb"
      method_id2_string = "0xa0712d68"
      method_id3_string = "0x3078f114"
      method_id4_string = "0x40993b26"

      {:ok, method1} = Data.cast(method_id1_string <> "ab0ba0")
      {:ok, method2} = Data.cast(method_id2_string <> "ab0ba0")
      {:ok, method3} = Data.cast(method_id3_string <> "ab0ba0")
      {:ok, method4} = Data.cast(method_id4_string <> "ab0ba0")

      for i <- 1..5 do
        insert(:internal_transaction,
          transaction: transaction,
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i,
          input: method1
        )
      end

      for i <- 6..10 do
        insert(:internal_transaction,
          transaction: transaction,
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i,
          input: method2
        )
      end

      5
      |> insert_list(:transaction, to_address_hash: contract_address.hash, to_address: contract_address, input: method2)
      |> with_block()

      5
      |> insert_list(:transaction, to_address_hash: contract_address.hash, to_address: contract_address, input: method3)
      |> with_block()

      method3_transaction =
        :transaction
        |> insert(
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          input: method3,
          has_token_transfers: true
        )
        |> with_block()

      method4_transaction =
        :transaction
        |> insert(
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          input: method4,
          has_token_transfers: true
        )
        |> with_block()

      5 |> insert_list(:token_transfer, transaction: method3_transaction)
      5 |> insert_list(:token_transfer, transaction: method4_transaction)

      request = get(conn, "/api/v2/advanced-filters", %{"methods" => "0xa0712d68,0x3078f114"})
      assert response = json_response(request, 200)

      assert Enum.all?(response["items"], fn item ->
               String.slice(item["method"], 0..9) in [method_id2_string, method_id3_string]
             end)

      assert Enum.count(response["items"]) == 21
    end

    test "filter by age", %{conn: conn} do
      [_, transaction_a, _, transaction_b, _] =
        for i <- 0..4 do
          tx = :transaction |> insert() |> with_block(status: :ok)

          insert(:internal_transaction,
            transaction: tx,
            transaction_index: tx.index,
            index: i + 1,
            block_hash: tx.block_hash,
            block_number: tx.block_number,
            block: tx.block
          )

          insert(:token_transfer,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i,
            block_hash: tx.block_hash,
            block: tx.block
          )

          tx
        end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "age_from" => DateTime.to_iso8601(transaction_a.block.timestamp),
          "age_to" => DateTime.to_iso8601(transaction_b.block.timestamp)
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 9
    end

    test "filter by from address include", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        transaction = :transaction |> insert() |> with_block()

        if i < 2 do
          :transaction |> insert(from_address_hash: address.hash, from_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            from_address_hash: address.hash,
            from_address: address,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            from_address_hash: address.hash,
            from_address: address,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"from_address_hashes_to_include" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by from address exclude", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        transaction = :transaction |> insert() |> with_block()

        if i < 4 do
          :transaction |> insert(from_address_hash: address.hash, from_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            from_address_hash: address.hash,
            from_address: address,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            from_address_hash: address.hash,
            from_address: address,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"from_address_hashes_to_exclude" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 7
    end

    test "filter by from address include and exclude", %{conn: conn} do
      address_to_include = insert(:address)
      address_to_exclude = insert(:address)

      for i <- 0..2 do
        transaction =
          :transaction
          |> insert(from_address_hash: address_to_exclude.hash, from_address: address_to_exclude)
          |> with_block()

        if i < 4 do
          :transaction
          |> insert(from_address_hash: address_to_include.hash, from_address: address_to_include)
          |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            from_address_hash: address_to_include.hash,
            from_address: address_to_include,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            from_address_hash: address_to_include.hash,
            from_address: address_to_include,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "from_address_hashes_to_include" => to_string(address_to_include.hash),
          "from_address_hashes_to_exclude" => to_string(address_to_exclude.hash)
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 9
    end

    test "filter by to address include", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        transaction = :transaction |> insert() |> with_block()

        if i < 2 do
          :transaction |> insert(to_address_hash: address.hash, to_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            to_address_hash: address.hash,
            to_address: address,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            to_address_hash: address.hash,
            to_address: address,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"to_address_hashes_to_include" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by to address exclude", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        transaction = :transaction |> insert() |> with_block()

        if i < 4 do
          :transaction |> insert(to_address_hash: address.hash, to_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            to_address_hash: address.hash,
            to_address: address,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            to_address_hash: address.hash,
            to_address: address,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"to_address_hashes_to_exclude" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 7
    end

    test "filter by to address include and exclude", %{conn: conn} do
      address_to_include = insert(:address)
      address_to_exclude = insert(:address)

      for i <- 0..2 do
        transaction =
          :transaction
          |> insert(to_address_hash: address_to_exclude.hash, to_address: address_to_exclude)
          |> with_block()

        if i < 4 do
          :transaction
          |> insert(to_address_hash: address_to_include.hash, to_address: address_to_include)
          |> with_block()

          insert(:internal_transaction,
            transaction: transaction,
            to_address_hash: address_to_include.hash,
            to_address: address_to_include,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer,
            to_address_hash: address_to_include.hash,
            to_address: address_to_include,
            transaction: transaction,
            block_number: transaction.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: transaction,
            block_hash: transaction.block_hash,
            block_number: transaction.block_number,
            transaction_index: transaction.index,
            index: i + 1
          )

          insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "to_address_hashes_to_include" => to_string(address_to_include.hash),
          "to_address_hashes_to_exclude" => to_string(address_to_exclude.hash)
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 9
    end

    test "filter by from and to address", %{conn: conn} do
      from_address = insert(:address)
      to_address = insert(:address)

      for i <- 0..8 do
        transaction = :transaction |> insert() |> with_block()

        cond do
          i < 2 ->
            :transaction |> insert(from_address_hash: from_address.hash, from_address: from_address) |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          i < 4 ->
            :transaction |> insert(to_address_hash: to_address.hash, to_address: to_address) |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              to_address_hash: to_address.hash,
              to_address: to_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          i < 6 ->
            :transaction
            |> insert(
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address
            )
            |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          true ->
            insert(:internal_transaction,
              transaction: transaction,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "from_address_hashes_to_include" => to_string(from_address.hash),
          "to_address_hashes_to_include" => to_string(to_address.hash),
          "address_relation" => "AnD"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by from and to address (intersect corner case)", %{conn: conn} do
      from_address = insert(:address)
      to_address = insert(:address)

      transaction =
        :transaction
        |> insert(
          from_address: from_address,
          from_address_hash: from_address.hash,
          to_address: to_address,
          to_address_hash: to_address.hash
        )
        |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        block_hash: transaction.block_hash,
        block_number: transaction.block_number,
        transaction_index: transaction.index,
        index: 51,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash
      )

      insert(:token_transfer,
        transaction: transaction,
        block_number: transaction.block_number,
        log_index: 51,
        from_address: from_address,
        from_address_hash: from_address.hash,
        to_address: to_address,
        to_address_hash: to_address.hash
      )

      for i <- 0..50 do
        transaction =
          :transaction |> insert(from_address: from_address, from_address_hash: from_address.hash) |> with_block()

        insert(:internal_transaction,
          transaction: transaction,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i + 1,
          from_address: from_address,
          from_address_hash: from_address.hash
        )

        insert(:token_transfer,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: i,
          from_address: from_address,
          from_address_hash: from_address.hash
        )

        transaction = :transaction |> insert(to_address: to_address, to_address_hash: to_address.hash) |> with_block()

        insert(:internal_transaction,
          transaction: transaction,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: i + 1,
          to_address: to_address,
          to_address_hash: to_address.hash
        )

        insert(:token_transfer,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: i,
          to_address: to_address,
          to_address_hash: to_address.hash
        )
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "from_address_hashes_to_include" => to_string(from_address.hash),
          "to_address_hashes_to_include" => to_string(to_address.hash),
          "address_relation" => "AnD"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 3
    end

    test "filter by from or to address", %{conn: conn} do
      from_address = insert(:address)
      to_address = insert(:address)

      for i <- 0..8 do
        transaction = :transaction |> insert() |> with_block()

        cond do
          i < 2 ->
            :transaction |> insert(from_address_hash: from_address.hash, from_address: from_address) |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          i < 4 ->
            :transaction |> insert(to_address_hash: to_address.hash, to_address: to_address) |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              to_address_hash: to_address.hash,
              to_address: to_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          i < 6 ->
            :transaction
            |> insert(
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address
            )
            |> with_block()

            insert(:internal_transaction,
              transaction: transaction,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: transaction,
              block_number: transaction.block_number,
              log_index: i
            )

          true ->
            insert(:internal_transaction,
              transaction: transaction,
              block_hash: transaction.block_hash,
              block_number: transaction.block_number,
              transaction_index: transaction.index,
              index: i + 1
            )

            insert(:token_transfer, transaction: transaction, block_number: transaction.block_number, log_index: i)
        end
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "from_address_hashes_to_include" => to_string(from_address.hash),
          "to_address_hashes_to_include" => to_string(to_address.hash)
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 18
    end

    test "filter by amount", %{conn: conn} do
      for i <- 0..4 do
        transaction = :transaction |> insert(value: i * 10 ** 18) |> with_block()

        insert(:internal_transaction,
          transaction: transaction,
          block_hash: transaction.block_hash,
          block_number: transaction.block_number,
          transaction_index: transaction.index,
          index: 1,
          value: i * 10 ** 18
        )

        token = insert(:token, decimals: 10)

        insert(:token_transfer,
          amount: i * 10 ** 10,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: 0
        )
      end

      request = get(conn, "/api/v2/advanced-filters", %{"amount_from" => "0.5", "amount_to" => "2.99"})
      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by token contract address include", %{conn: conn} do
      token_a = insert(:token)
      token_b = insert(:token)
      token_c = insert(:token)

      transaction = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: 0
        )
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "token_contract_address_hashes_to_include" =>
            "#{token_b.contract_address_hash},#{token_c.contract_address_hash}"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by token contract address exclude", %{conn: conn} do
      token_a = insert(:token)
      token_b = insert(:token)
      token_c = insert(:token)

      transaction = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: 0
        )
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "token_contract_address_hashes_to_exclude" =>
            "#{token_b.contract_address_hash},#{token_c.contract_address_hash}"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 4
    end

    test "filter by token contract address include with native", %{conn: conn} do
      token_a = insert(:token)
      token_b = insert(:token)
      token_c = insert(:token)

      transaction = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: 0
        )
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "token_contract_address_hashes_to_include" =>
            "#{token_b.contract_address_hash},#{token_c.contract_address_hash},native"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 7
    end

    test "filter by token contract address exclude with native", %{conn: conn} do
      token_a = insert(:token)
      token_b = insert(:token)
      token_c = insert(:token)

      transaction = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: transaction,
          block_number: transaction.block_number,
          log_index: 0
        )
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "token_contract_address_hashes_to_exclude" =>
            "#{token_b.contract_address_hash},#{token_c.contract_address_hash},native"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 3
    end

    test "correct query with all filters and pagination", %{conn: conn} do
      for address_relation <- [:or, :and] do
        method_id_string = "0xa9059cbb"
        {:ok, method} = Data.cast(method_id_string <> "ab0ba0")
        transaction_from_address = insert(:address)
        transaction_to_address = insert(:address)
        token_transfer_from_address = insert(:address)
        token_transfer_to_address = insert(:address)
        token = insert(:token)
        {:ok, burn_address_hash} = Hash.Address.cast(SmartContract.burn_address_hash_string())

        insert_list(5, :transaction)

        transactions =
          for _ <- 0..29 do
            transaction =
              insert(:transaction,
                from_address: transaction_from_address,
                from_address_hash: transaction_from_address.hash,
                to_address: transaction_to_address,
                to_address_hash: transaction_to_address.hash,
                value: Enum.random(0..1_000_000),
                input: method,
                has_token_transfers: true
              )
              |> with_block()

            insert(:token_transfer,
              transaction: transaction,
              block_number: transaction.block_number,
              amount: Enum.random(0..1_000_000),
              from_address: token_transfer_from_address,
              from_address_hash: token_transfer_from_address.hash,
              to_address: token_transfer_to_address,
              to_address_hash: token_transfer_to_address.hash,
              token_contract_address: token.contract_address,
              token_contract_address_hash: token.contract_address_hash
            )

            transaction
          end

        insert_list(5, :transaction)

        from_timestamp = List.first(transactions).block.timestamp
        to_timestamp = List.last(transactions).block.timestamp

        params = %{
          "tx_types" => "coin_transfer,ERC-20",
          "methods" => method_id_string,
          "age_from" => from_timestamp |> DateTime.to_iso8601(),
          "age_to" => to_timestamp |> DateTime.to_iso8601(),
          "from_address_hashes_to_include" => "#{transaction_from_address.hash},#{token_transfer_from_address.hash}",
          "to_address_hashes_to_include" => "#{transaction_to_address.hash},#{token_transfer_to_address.hash}",
          "address_relation" => to_string(address_relation),
          "amount_from" => "0",
          "amount_to" => "1000000",
          "token_contract_address_hashes_to_include" => "native,#{token.contract_address_hash}",
          "token_contract_address_hashes_to_exclude" => "#{burn_address_hash}"
        }

        request =
          get(conn, "/api/v2/advanced-filters", params)

        assert response = json_response(request, 200)
        request_2nd_page = get(conn, "/api/v2/advanced-filters", Map.merge(params, response["next_page_params"]))
        assert response_2nd_page = json_response(request_2nd_page, 200)

        check_paginated_response(
          AdvancedFilter.list(
            tx_types: ["COIN_TRANSFER", "ERC-20"],
            methods: ["0xa9059cbb"],
            age: [from: from_timestamp, to: to_timestamp],
            from_address_hashes: [
              include: [transaction_from_address.hash, token_transfer_from_address.hash],
              exclude: nil
            ],
            to_address_hashes: [
              include: [transaction_to_address.hash, token_transfer_to_address.hash],
              exclude: nil
            ],
            address_relation: address_relation,
            amount: [from: Decimal.new("0"), to: Decimal.new("1000000")],
            token_contract_address_hashes: [
              include: [
                "native",
                token.contract_address_hash
              ],
              exclude: [burn_address_hash]
            ],
            api?: true
          ),
          response["items"],
          response_2nd_page["items"]
        )
      end
    end
  end

  describe "/advanced_filters/methods?q=" do
    test "returns empty list if method does not exist", %{conn: conn} do
      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "foo"})
      assert response = json_response(request, 200)
      assert response == []
    end

    test "finds method by name", %{conn: conn} do
      insert(:contract_method)
      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "set"})
      assert response = json_response(request, 200)
      assert response == [%{"method_id" => "0x60fe47b1", "name" => "set"}]
    end

    test "finds method by id", %{conn: conn} do
      insert(:contract_method)
      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "0x60fe47b1"})
      assert response = json_response(request, 200)
      assert response == [%{"method_id" => "0x60fe47b1", "name" => "set"}]
    end

    test "finds method with method id starting with 0x", %{conn: conn} do
      abi =
        %{
          "constant" => false,
          "inputs" => [%{"name" => "x", "type" => "uint64"}, %{"name" => "y", "type" => "address"}],
          "name" => "getAccess",
          "outputs" => [],
          "payable" => false,
          "stateMutability" => "nonpayable",
          "type" => "function"
        }

      [parsed_method] = ABI.parse_specification([abi])

      insert(:contract_method,
        abi: abi,
        identifier: parsed_method.method_id
      )

      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "0x3078f114"})
      assert response = json_response(request, 200)
      assert response == [%{"method_id" => "0x3078f114", "name" => "getAccess"}]
    end

    test "returns method id without name if q is valid method id", %{conn: conn} do
      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "0x60fe47b1"})
      assert response = json_response(request, 200)
      assert response == [%{"method_id" => "0x60fe47b1", "name" => ""}]
    end
  end

  defp check_paginated_response(all_advanced_filters, first_page, second_page) do
    assert all_advanced_filters
           |> Enum.map(
             &{&1.block_number, &1.transaction_index, &1.internal_transaction_index, &1.token_transfer_index,
              &1.token_transfer_batch_index}
           ) ==
             Enum.map(
               first_page ++ second_page,
               &{&1["block_number"], &1["transaction_index"], &1["internal_transaction_index"],
                &1["token_transfer_index"], &1["token_transfer_batch_index"]}
             )
  end
end
