defmodule BlockScoutWeb.API.V2.AdvancedFilterControllerTest do
  use BlockScoutWeb.ConnCase

  import Mox

  alias Explorer.Chain.{AdvancedFilter, Data}
  alias Explorer.{Factory, TestHelper}

  describe "/advanced_filters" do
    test "empty list", %{conn: conn} do
      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      assert response["items"] == []
      assert response["next_page_params"] == nil
    end

    test "get and paginate advanced filter (transactions split between pages)", %{conn: conn} do
      first_tx = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_tx)

      for i <- 0..2 do
        insert(:internal_transaction,
          transaction: first_tx,
          block_hash: first_tx.block_hash,
          index: i,
          block_index: i
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
      first_tx = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_tx)

      for i <- 0..2 do
        insert(:internal_transaction,
          transaction: first_tx,
          block_hash: first_tx.block_hash,
          index: i,
          block_index: i
        )
      end

      second_tx = :transaction |> insert() |> with_block()
      insert_list(50, :token_transfer, transaction: second_tx, block_number: second_tx.block_number)

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])
      assert response_2nd_page = json_response(request_2nd_page, 200)

      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "get and paginate advanced filter (batch token transfers split between pages)", %{conn: conn} do
      first_tx = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_tx)

      for i <- 0..2 do
        insert(:internal_transaction,
          transaction: first_tx,
          block_hash: first_tx.block_hash,
          index: i,
          block_index: i
        )
      end

      second_tx = :transaction |> insert() |> with_block()

      insert_list(5, :token_transfer,
        transaction: second_tx,
        block_number: second_tx.block_number,
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
      first_tx = :transaction |> insert() |> with_block()
      insert_list(3, :token_transfer, transaction: first_tx)

      for i <- 0..2 do
        insert(:internal_transaction,
          transaction: first_tx,
          block_hash: first_tx.block_hash,
          index: i,
          block_index: i
        )
      end

      second_tx = :transaction |> insert() |> with_block()

      for i <- 0..49 do
        insert(:internal_transaction,
          transaction: second_tx,
          block_hash: second_tx.block_hash,
          index: i,
          block_index: i
        )
      end

      request = get(conn, "/api/v2/advanced-filters")
      assert response = json_response(request, 200)
      request_2nd_page = get(conn, "/api/v2/advanced-filters", response["next_page_params"])

      assert response_2nd_page = json_response(request_2nd_page, 200)
      check_paginated_response(AdvancedFilter.list(), response["items"], response_2nd_page["items"])
    end

    test "filter by tx_type", %{conn: conn} do
      30 |> insert_list(:transaction) |> with_block()

      tx = insert(:transaction) |> with_block()

      for token_type <- ~w(ERC-20 ERC-404 ERC-721 ERC-1155),
          _ <- 0..4 do
        insert(:token_transfer, transaction: tx, token_type: token_type)
      end

      tx = :transaction |> insert() |> with_block()

      for i <- 0..29 do
        insert(:internal_transaction,
          transaction: tx,
          block_hash: tx.block_hash,
          index: i,
          block_index: i
        )
      end

      for tx_type_filter_string <-
            ~w(COIN_TRANSFER COIN_TRANSFER,ERC-404 ERC-721,ERC-1155 ERC-20,COIN_TRANSFER,ERC-1155) do
        tx_type_filter = tx_type_filter_string |> String.split(",")
        request = get(conn, "/api/v2/advanced-filters", %{"tx_types" => tx_type_filter_string})
        assert response = json_response(request, 200)

        assert Enum.all?(response["items"], fn item -> String.upcase(item["type"]) in tx_type_filter end)

        if response["next_page_params"] do
          request_2nd_page =
            get(
              conn,
              "/api/v2/advanced-filters",
              Map.merge(%{"tx_types" => tx_type_filter_string}, response["next_page_params"])
            )

          assert response_2nd_page = json_response(request_2nd_page, 200)

          assert Enum.all?(response_2nd_page["items"], fn item -> String.upcase(item["type"]) in tx_type_filter end)

          check_paginated_response(
            AdvancedFilter.list(tx_types: tx_type_filter),
            response["items"],
            response_2nd_page["items"]
          )
        end
      end
    end

    test "filter by methods", %{conn: conn} do
      TestHelper.get_eip1967_implementation_zero_addresses()

      tx = :transaction |> insert() |> with_block()

      smart_contract = build(:smart_contract)

      contract_address =
        insert(:address,
          hash: address_hash(),
          verified: true,
          contract_code: Factory.contract_code_info().bytecode,
          smart_contract: smart_contract
        )

      method_id1_string = "0xa9059cbb"
      method_id2_string = "0xa0712d68"
      method_id3_string = "0x095ea7b3"
      method_id4_string = "0x40993b26"

      {:ok, method1} = Data.cast(method_id1_string <> "ab0ba0")
      {:ok, method2} = Data.cast(method_id2_string <> "ab0ba0")
      {:ok, method3} = Data.cast(method_id3_string <> "ab0ba0")
      {:ok, method4} = Data.cast(method_id4_string <> "ab0ba0")

      for i <- 0..4 do
        insert(:internal_transaction,
          transaction: tx,
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          block_hash: tx.block_hash,
          index: i,
          block_index: i,
          input: method1
        )
      end

      for i <- 5..9 do
        insert(:internal_transaction,
          transaction: tx,
          to_address_hash: contract_address.hash,
          to_address: contract_address,
          block_hash: tx.block_hash,
          index: i,
          block_index: i,
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
        |> insert(to_address_hash: contract_address.hash, to_address: contract_address, input: method3)
        |> with_block()

      method4_transaction =
        :transaction
        |> insert(to_address_hash: contract_address.hash, to_address: contract_address, input: method4)
        |> with_block()

      5 |> insert_list(:token_transfer, transaction: method3_transaction)
      5 |> insert_list(:token_transfer, transaction: method4_transaction)

      request = get(conn, "/api/v2/advanced-filters", %{"methods" => "0xa0712d68,0x095ea7b3"})
      assert response = json_response(request, 200)

      assert Enum.all?(response["items"], fn item ->
               String.slice(item["method"], 0..9) in [method_id2_string, method_id3_string]
             end)

      assert Enum.count(response["items"]) == 21
    end

    test "filter by age", %{conn: conn} do
      first_timestamp = ~U[2023-12-12 00:00:00.000000Z]

      for i <- 0..4 do
        tx = :transaction |> insert() |> with_block(block_timestamp: Timex.shift(first_timestamp, days: i))

        insert(:internal_transaction,
          transaction: tx,
          block_hash: tx.block_hash,
          index: i,
          block_index: i
        )

        insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
      end

      request =
        get(conn, "/api/v2/advanced-filters", %{
          "age_from" => "2023-12-14T00:00:00Z",
          "age_to" => "2023-12-16T00:00:00Z"
        })

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 9
    end

    test "filter by from address include", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        tx = :transaction |> insert() |> with_block()

        if i < 2 do
          :transaction |> insert(from_address_hash: address.hash, from_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            from_address_hash: address.hash,
            from_address: address,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            from_address_hash: address.hash,
            from_address: address,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"from_address_hashes_to_include" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by from address exclude", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        tx = :transaction |> insert() |> with_block()

        if i < 4 do
          :transaction |> insert(from_address_hash: address.hash, from_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            from_address_hash: address.hash,
            from_address: address,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            from_address_hash: address.hash,
            from_address: address,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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
        tx =
          :transaction
          |> insert(from_address_hash: address_to_exclude.hash, from_address: address_to_exclude)
          |> with_block()

        if i < 4 do
          :transaction
          |> insert(from_address_hash: address_to_include.hash, from_address: address_to_include)
          |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            from_address_hash: address_to_include.hash,
            from_address: address_to_include,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            from_address_hash: address_to_include.hash,
            from_address: address_to_include,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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
        tx = :transaction |> insert() |> with_block()

        if i < 2 do
          :transaction |> insert(to_address_hash: address.hash, to_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            to_address_hash: address.hash,
            to_address: address,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            to_address_hash: address.hash,
            to_address: address,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
        end
      end

      request = get(conn, "/api/v2/advanced-filters", %{"to_address_hashes_to_include" => to_string(address.hash)})

      assert response = json_response(request, 200)

      assert Enum.count(response["items"]) == 6
    end

    test "filter by to address exclude", %{conn: conn} do
      address = insert(:address)

      for i <- 0..4 do
        tx = :transaction |> insert() |> with_block()

        if i < 4 do
          :transaction |> insert(to_address_hash: address.hash, to_address: address) |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            to_address_hash: address.hash,
            to_address: address,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            to_address_hash: address.hash,
            to_address: address,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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
        tx =
          :transaction
          |> insert(to_address_hash: address_to_exclude.hash, to_address: address_to_exclude)
          |> with_block()

        if i < 4 do
          :transaction
          |> insert(to_address_hash: address_to_include.hash, to_address: address_to_include)
          |> with_block()

          insert(:internal_transaction,
            transaction: tx,
            to_address_hash: address_to_include.hash,
            to_address: address_to_include,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer,
            to_address_hash: address_to_include.hash,
            to_address: address_to_include,
            transaction: tx,
            block_number: tx.block_number,
            log_index: i
          )
        else
          insert(:internal_transaction,
            transaction: tx,
            block_hash: tx.block_hash,
            index: i,
            block_index: i
          )

          insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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
        tx = :transaction |> insert() |> with_block()

        cond do
          i < 2 ->
            :transaction |> insert(from_address_hash: from_address.hash, from_address: from_address) |> with_block()

            insert(:internal_transaction,
              transaction: tx,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: tx,
              block_number: tx.block_number,
              log_index: i
            )

          i < 4 ->
            :transaction |> insert(to_address_hash: to_address.hash, to_address: to_address) |> with_block()

            insert(:internal_transaction,
              transaction: tx,
              to_address_hash: to_address.hash,
              to_address: to_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              transaction: tx,
              block_number: tx.block_number,
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
              transaction: tx,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: tx,
              block_number: tx.block_number,
              log_index: i
            )

          true ->
            insert(:internal_transaction,
              transaction: tx,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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

    test "filter by from or to address", %{conn: conn} do
      from_address = insert(:address)
      to_address = insert(:address)

      for i <- 0..8 do
        tx = :transaction |> insert() |> with_block()

        cond do
          i < 2 ->
            :transaction |> insert(from_address_hash: from_address.hash, from_address: from_address) |> with_block()

            insert(:internal_transaction,
              transaction: tx,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: tx,
              block_number: tx.block_number,
              log_index: i
            )

          i < 4 ->
            :transaction |> insert(to_address_hash: to_address.hash, to_address: to_address) |> with_block()

            insert(:internal_transaction,
              transaction: tx,
              to_address_hash: to_address.hash,
              to_address: to_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              transaction: tx,
              block_number: tx.block_number,
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
              transaction: tx,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer,
              to_address_hash: to_address.hash,
              to_address: to_address,
              from_address_hash: from_address.hash,
              from_address: from_address,
              transaction: tx,
              block_number: tx.block_number,
              log_index: i
            )

          true ->
            insert(:internal_transaction,
              transaction: tx,
              block_hash: tx.block_hash,
              index: i,
              block_index: i
            )

            insert(:token_transfer, transaction: tx, block_number: tx.block_number, log_index: i)
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
        tx = :transaction |> insert(value: i * 10 ** 18) |> with_block()

        insert(:internal_transaction,
          transaction: tx,
          block_hash: tx.block_hash,
          index: 0,
          block_index: 0,
          value: i * 10 ** 18
        )

        token = insert(:token, decimals: 10)

        insert(:token_transfer,
          amount: i * 10 ** 10,
          token_contract_address: token.contract_address,
          transaction: tx,
          block_number: tx.block_number,
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

      tx = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: tx,
          block_number: tx.block_number,
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

      tx = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: tx,
          block_number: tx.block_number,
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

      tx = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: tx,
          block_number: tx.block_number,
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

      tx = :transaction |> insert() |> with_block()

      for token <- [token_a, token_b, token_c, token_a, token_b, token_c, token_a, token_b, token_c] do
        insert(:token_transfer,
          token_contract_address: token.contract_address,
          transaction: tx,
          block_number: tx.block_number,
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
  end

  describe "/advanced_filters/methods?q=" do
    test "returns 404 if method does not exist", %{conn: conn} do
      request = get(conn, "/api/v2/advanced-filters/methods", %{"q" => "foo"})
      assert response = json_response(request, 404)
      assert response["message"] == "Not found"
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
