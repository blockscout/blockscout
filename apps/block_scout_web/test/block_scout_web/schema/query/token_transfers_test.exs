defmodule BlockScoutWeb.Schema.Query.TokenTransfersTest do
  use BlockScoutWeb.ConnCase

  describe "token_transfers field" do
    test "with valid argument, returns all expected fields", %{conn: conn} do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction, token_ids: [5], amounts: [10])
      address_hash = to_string(token_transfer.token_contract_address_hash)

      query = """
      query ($token_contract_address_hash: AddressHash!, $first: Int!) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, first: $first) {
          edges {
            node {
              amount
              amounts
              block_number
              log_index
              token_id
              token_ids
              from_address_hash
              to_address_hash
              token_contract_address_hash
              transaction_hash
            }
          }
        }
      }
      """

      variables = %{
        "token_contract_address_hash" => address_hash,
        "first" => 1
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "token_transfers" => %{
                   "edges" => [
                     %{
                       "node" => %{
                         "amount" => to_string(token_transfer.amount),
                         "amounts" => Enum.map(token_transfer.amounts, &to_string/1),
                         "block_number" => token_transfer.block_number,
                         "log_index" => token_transfer.log_index,
                         "token_id" => token_transfer.token_id,
                         "token_ids" => Enum.map(token_transfer.token_ids, &to_string/1),
                         "from_address_hash" => to_string(token_transfer.from_address_hash),
                         "to_address_hash" => to_string(token_transfer.to_address_hash),
                         "token_contract_address_hash" => to_string(token_transfer.token_contract_address_hash),
                         "transaction_hash" => to_string(token_transfer.transaction_hash)
                       }
                     }
                   ]
                 }
               }
             }
    end

    test "with token contract address with zero token transfers", %{conn: conn} do
      address = insert(:contract_address)

      query = """
      query ($token_contract_address_hash: AddressHash!, $first: Int!) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, first: $first) {
          edges {
            node {
              amount
              block_number
              log_index
              token_id
              from_address_hash
              to_address_hash
              token_contract_address_hash
              transaction_hash
            }
          }
        }
      }
      """

      variables = %{
        "token_contract_address_hash" => to_string(address.hash),
        "first" => 10
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "token_transfers" => %{
                   "edges" => []
                 }
               }
             }
    end

    test "complexity correlates to first or last argument", %{conn: conn} do
      address = insert(:contract_address)

      query1 = """
      query ($token_contract_address_hash: AddressHash!, $first: Int!) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, first: $first) {
          edges {
            node {
              amount
              from_address_hash
              to_address_hash
            }
          }
        }
      }
      """

      variables1 = %{
        "token_contract_address_hash" => to_string(address.hash),
        "first" => 55
      }

      response1 =
        conn
        |> post("/graphql", query: query1, variables: variables1)
        |> json_response(200)

      %{"errors" => [response1_error1, response1_error2]} = response1

      assert response1_error1["message"] =~ ~s(Field token_transfers is too complex)
      assert response1_error2["message"] =~ ~s(Operation is too complex)

      query2 = """
      query ($token_contract_address_hash: AddressHash!, $last: Int!) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, last: $last) {
          edges {
            node {
              amount
              from_address_hash
              to_address_hash
            }
          }
        }
      }
      """

      variables2 = %{
        "token_contract_address_hash" => to_string(address.hash),
        "last" => 55
      }

      response2 =
        conn
        |> post("/graphql", query: query2, variables: variables2)
        |> json_response(200)

      %{"errors" => [response2_error1, response2_error2]} = response2
      assert response2_error1["message"] =~ ~s(Field token_transfers is too complex)
      assert response2_error2["message"] =~ ~s(Operation is too complex)
    end

    test "with 'last' and 'count' arguments", %{conn: conn} do
      # "`last: N` must always be acompanied by either a `before:` argument to
      # the query, or an explicit `count:` option to the `from_query` call.
      # Otherwise it is impossible to derive the required offset."
      # https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html#from_query/4
      #
      # This test ensures support for a 'count' argument.

      address = insert(:contract_address)

      blocks = insert_list(2, :block)

      [transaction1, transaction2] =
        for block <- blocks do
          :transaction
          |> insert()
          |> with_block(block)
        end

      token_transfer_attrs1 = %{
        block_number: transaction1.block_number,
        transaction: transaction1,
        token_contract_address: address
      }

      token_transfer_attrs2 = %{
        block_number: transaction2.block_number,
        transaction: transaction2,
        token_contract_address: address
      }

      insert(:token_transfer, token_transfer_attrs1)
      insert(:token_transfer, token_transfer_attrs2)

      query = """
      query ($token_contract_address_hash: AddressHash!, $last: Int!, $count: Int) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, last: $last, count: $count) {
          edges {
            node {
              transaction_hash
            }
          }
        }
      }
      """

      variables = %{
        "token_contract_address_hash" => to_string(address.hash),
        "last" => 1,
        "count" => 2
      }

      [token_transfer] =
        conn
        |> post("/graphql", query: query, variables: variables)
        |> json_response(200)
        |> get_in(["data", "token_transfers", "edges"])

      assert token_transfer["node"]["transaction_hash"] == to_string(transaction1.hash)
    end

    test "pagination support with 'first' and 'after' arguments", %{conn: conn} do
      address = insert(:contract_address)

      blocks = insert_list(3, :block)

      [transaction1, transaction2, transaction3] =
        transactions =
        for block <- blocks do
          :transaction
          |> insert()
          |> with_block(block)
        end

      for transaction <- transactions do
        token_transfer_attrs = %{
          block_number: transaction.block_number,
          transaction: transaction,
          token_contract_address: address
        }

        insert(:token_transfer, token_transfer_attrs)
      end

      query1 = """
      query ($token_contract_address_hash: AddressHash!, $first: Int!) {
        token_transfers(token_contract_address_hash: $token_contract_address_hash, first: $first) {
          page_info {
            has_next_page
            has_previous_page
          }
          edges {
            node {
              transaction_hash
            }
            cursor
          }
        }
      }
      """

      variables1 = %{
        "token_contract_address_hash" => to_string(address.hash),
        "first" => 1
      }

      conn = post(conn, "/graphql", query: query1, variables: variables1)

      %{"data" => %{"token_transfers" => page1}} = json_response(conn, 200)

      assert page1["page_info"] == %{"has_next_page" => true, "has_previous_page" => false}
      assert Enum.all?(page1["edges"], &(&1["node"]["transaction_hash"] == to_string(transaction3.hash)))

      last_cursor_page1 =
        page1
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      query2 = """
      query ($token_contract_address_hash: AddressHash!, $first: Int!, $after: String!) {
      token_transfers(token_contract_address_hash: $token_contract_address_hash, first: $first, after: $after) {
          page_info {
            has_next_page
            has_previous_page
          }
          edges {
            node {
              transaction_hash
            }
            cursor
          }
        }
      }
      """

      variables2 = %{
        "token_contract_address_hash" => to_string(address.hash),
        "first" => 1,
        "after" => last_cursor_page1
      }

      conn = post(conn, "/graphql", query: query2, variables: variables2)

      %{"data" => %{"token_transfers" => page2}} = json_response(conn, 200)

      assert page2["page_info"] == %{"has_next_page" => true, "has_previous_page" => true}
      assert Enum.all?(page2["edges"], &(&1["node"]["transaction_hash"] == to_string(transaction2.hash)))

      last_cursor_page2 =
        page2
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      variables3 = %{
        "token_contract_address_hash" => to_string(address.hash),
        "first" => 1,
        "after" => last_cursor_page2
      }

      conn = post(conn, "/graphql", query: query2, variables: variables3)

      %{"data" => %{"token_transfers" => page3}} = json_response(conn, 200)

      assert page3["page_info"] == %{"has_next_page" => false, "has_previous_page" => true}
      assert Enum.all?(page3["edges"], &(&1["node"]["transaction_hash"] == to_string(transaction1.hash)))
    end
  end
end
