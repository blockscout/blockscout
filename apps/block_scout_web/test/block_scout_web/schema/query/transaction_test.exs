defmodule BlockScoutWeb.Schema.Query.TransactionTest do
  use BlockScoutWeb.ConnCase

  describe "transaction field" do
    test "with valid argument 'hash', returns all expected fields", %{conn: conn} do
      block = insert(:block)

      transaction =
        :transaction
        |> insert()
        |> with_block(block, status: :ok)

      query = """
      query ($hash: FullHash!) {
        transaction(hash: $hash) {
          hash
          block_number
          cumulative_gas_used
          error
          gas
          gas_price
          gas_used
          index
          input
          nonce
          r
          s
          status
          v
          value
          from_address_hash
          to_address_hash
          created_contract_address_hash
        }
      }
      """

      variables = %{"hash" => to_string(transaction.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "transaction" => %{
                   "hash" => to_string(transaction.hash),
                   "block_number" => transaction.block_number,
                   "cumulative_gas_used" => to_string(transaction.cumulative_gas_used),
                   "error" => transaction.error,
                   "gas" => to_string(transaction.gas),
                   "gas_price" => to_string(transaction.gas_price.value),
                   "gas_used" => to_string(transaction.gas_used),
                   "index" => transaction.index,
                   "input" => to_string(transaction.input),
                   "nonce" => to_string(transaction.nonce),
                   "r" => to_string(transaction.r),
                   "s" => to_string(transaction.s),
                   "status" => transaction.status |> to_string() |> String.upcase(),
                   "v" => to_string(transaction.v),
                   "value" => to_string(transaction.value.value),
                   "from_address_hash" => to_string(transaction.from_address_hash),
                   "to_address_hash" => to_string(transaction.to_address_hash),
                   "created_contract_address_hash" => nil
                 }
               }
             }
    end

    test "errors for non-existent transaction hash", %{conn: conn} do
      transaction = build(:transaction)

      query = """
      query ($hash: FullHash!) {
        transaction(hash: $hash) {
          status
        }
      }
      """

      variables = %{"hash" => to_string(transaction.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] == "Transaction not found."
    end

    test "errors if argument 'hash' is missing", %{conn: conn} do
      query = """
      {
        transaction {
          status
        }
      }
      """

      conn = get(conn, "/graphql", query: query)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] == ~s(In argument "hash": Expected type "FullHash!", found null.)
    end

    test "errors if argument 'hash' is not a 'FullHash'", %{conn: conn} do
      query = """
      query ($hash: FullHash!) {
        transaction(hash: $hash) {
          status
        }
      }
      """

      variables = %{"hash" => "0x000"}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Argument "hash" has invalid value)
    end
  end

  describe "transaction internal_transactions field" do
    test "returns all expected internal_transaction fields", %{conn: conn} do
      address = insert(:address)
      contract_address = insert(:contract_address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_contract_creation(contract_address)
        |> with_block(block)

      internal_transaction_attributes = %{
        transaction: transaction,
        index: 0,
        from_address: address,
        call_type: :call,
        block_hash: transaction.block_hash,
        block_index: 0
      }

      internal_transaction =
        :internal_transaction_create
        |> insert(internal_transaction_attributes)
        |> with_contract_creation(contract_address)

      query = """
      query ($hash: FullHash!, $first: Int!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first) {
            edges {
              node {
                call_type
                created_contract_code
                error
                gas
                gas_used
                index
                init
                input
                output
                trace_address
                type
                value
                block_number
                transaction_index
                created_contract_address_hash
                from_address_hash
                to_address_hash
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(transaction.hash),
        "first" => 1
      }

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "transaction" => %{
                   "internal_transactions" => %{
                     "edges" => [
                       %{
                         "node" => %{
                           "call_type" => internal_transaction.call_type |> to_string() |> String.upcase(),
                           "created_contract_code" => to_string(internal_transaction.created_contract_code),
                           "error" => internal_transaction.error,
                           "gas" => to_string(internal_transaction.gas),
                           "gas_used" => to_string(internal_transaction.gas_used),
                           "index" => internal_transaction.index,
                           "init" => to_string(internal_transaction.init),
                           "input" => nil,
                           "output" => nil,
                           "trace_address" => Jason.encode!(internal_transaction.trace_address),
                           "type" => internal_transaction.type |> to_string() |> String.upcase(),
                           "value" => to_string(internal_transaction.value.value),
                           "block_number" => internal_transaction.block_number,
                           "transaction_index" => internal_transaction.transaction_index,
                           "created_contract_address_hash" =>
                             to_string(internal_transaction.created_contract_address_hash),
                           "from_address_hash" => to_string(internal_transaction.from_address_hash),
                           "to_address_hash" => nil,
                           "transaction_hash" => to_string(internal_transaction.transaction_hash)
                         }
                       }
                     ]
                   }
                 }
               }
             }
    end

    test "with transaction with zero internal transactions", %{conn: conn} do
      address = insert(:address)

      block = insert(:block)

      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block(block)

      query = """
      query ($hash: FullHash!, $first: Int!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first) {
            edges {
              node {
                index
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(transaction.hash),
        "first" => 1
      }

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "transaction" => %{
                   "internal_transactions" => %{
                     "edges" => []
                   }
                 }
               }
             }
    end

    test "internal transactions are ordered by ascending index", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 2,
        block_hash: transaction.block_hash,
        block_index: 2
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 1,
        block_hash: transaction.block_hash,
        block_index: 1
      )

      query = """
      query ($hash: FullHash!, $first: Int!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first) {
            edges {
              node {
                index
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(transaction.hash),
        "first" => 3
      }

      response =
        conn
        |> get("/graphql", query: query, variables: variables)
        |> json_response(200)

      internal_transactions = get_in(response, ["data", "transaction", "internal_transactions", "edges"])

      index_order = Enum.map(internal_transactions, & &1["node"]["index"])

      assert index_order == Enum.sort(index_order)
    end

    test "complexity correlates to first or last argument", %{conn: conn} do
      transaction = insert(:transaction)

      query1 = """
      query ($hash: FullHash!, $first: Int!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first) {
            edges {
              node {
                index
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables1 = %{
        "hash" => to_string(transaction.hash),
        "first" => 55
      }

      response1 =
        conn
        |> get("/graphql", query: query1, variables: variables1)
        |> json_response(200)

      assert %{"errors" => [error1, error2, error3]} = response1
      assert error1["message"] =~ ~s(Field internal_transactions is too complex)
      assert error2["message"] =~ ~s(Field transaction is too complex)
      assert error3["message"] =~ ~s(Operation is too complex)

      query2 = """
      query ($hash: FullHash!, $last: Int!, $count: Int!) {
        transaction(hash: $hash) {
          internal_transactions(last: $last, count: $count) {
            edges {
              node {
                index
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables2 = %{
        "hash" => to_string(transaction.hash),
        "last" => 55,
        "count" => 100
      }

      response2 =
        conn
        |> get("/graphql", query: query2, variables: variables2)
        |> json_response(200)

      assert %{"errors" => [error1, error2, error3]} = response2
      assert error1["message"] =~ ~s(Field internal_transactions is too complex)
      assert error2["message"] =~ ~s(Field transaction is too complex)
      assert error3["message"] =~ ~s(Operation is too complex)
    end

    test "with 'last' and 'count' arguments", %{conn: conn} do
      # "`last: N` must always be acompanied by either a `before:` argument to
      # the query, or an explicit `count:` option to the `from_query` call.
      # Otherwise it is impossible to derive the required offset."
      # https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html#from_query/4
      #
      # This test ensures support for a 'count' argument.

      transaction = insert(:transaction) |> with_block()

      insert(:internal_transaction,
        transaction: transaction,
        index: 2,
        block_hash: transaction.block_hash,
        block_index: 2
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 0,
        block_hash: transaction.block_hash,
        block_index: 0
      )

      insert(:internal_transaction,
        transaction: transaction,
        index: 1,
        block_hash: transaction.block_hash,
        block_index: 1
      )

      query = """
      query ($hash: FullHash!, $last: Int!, $count: Int!) {
        transaction(hash: $hash) {
          internal_transactions(last: $last, count: $count) {
            edges {
              node {
                index
                transaction_hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(transaction.hash),
        "last" => 1,
        "count" => 3
      }

      [internal_transaction] =
        conn
        |> get("/graphql", query: query, variables: variables)
        |> json_response(200)
        |> get_in(["data", "transaction", "internal_transactions", "edges"])

      assert internal_transaction["node"]["index"] == 2
    end

    test "pagination support with 'first' and 'after' arguments", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      for index <- 0..5 do
        insert(:internal_transaction_create,
          transaction: transaction,
          index: index,
          block_hash: transaction.block_hash,
          block_index: index
        )
      end

      query1 = """
      query ($hash: AddressHash!, $first: Int!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first) {
            page_info {
              has_next_page
              has_previous_page
            }
            edges {
              node {
                index
                transaction_hash
              }
              cursor
            }
          }
        }
      }
      """

      variables1 = %{
        "hash" => to_string(transaction.hash),
        "first" => 2
      }

      conn = get(conn, "/graphql", query: query1, variables: variables1)

      %{"data" => %{"transaction" => %{"internal_transactions" => page1}}} = json_response(conn, 200)

      assert page1["page_info"] == %{"has_next_page" => true, "has_previous_page" => false}
      assert Enum.all?(page1["edges"], &(&1["node"]["index"] in 0..1))

      last_cursor_page1 =
        page1
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      query2 = """
      query ($hash: AddressHash!, $first: Int!, $after: ID!) {
        transaction(hash: $hash) {
          internal_transactions(first: $first, after: $after) {
            page_info {
              has_next_page
              has_previous_page
            }
            edges {
              node {
                index
                transaction_hash
              }
              cursor
            }
          }
        }
      }
      """

      variables2 = %{
        "hash" => to_string(transaction.hash),
        "first" => 2,
        "after" => last_cursor_page1
      }

      page2 =
        conn
        |> get("/graphql", query: query2, variables: variables2)
        |> json_response(200)
        |> get_in(["data", "transaction", "internal_transactions"])

      assert page2["page_info"] == %{"has_next_page" => true, "has_previous_page" => true}
      assert Enum.all?(page2["edges"], &(&1["node"]["index"] in 2..3))

      last_cursor_page2 =
        page2
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      variables3 = %{
        "hash" => to_string(transaction.hash),
        "first" => 2,
        "after" => last_cursor_page2
      }

      page3 =
        conn
        |> get("/graphql", query: query2, variables: variables3)
        |> json_response(200)
        |> get_in(["data", "transaction", "internal_transactions"])

      assert page3["page_info"] == %{"has_next_page" => false, "has_previous_page" => true}
      assert Enum.all?(page3["edges"], &(&1["node"]["index"] in 4..5))
    end
  end
end
