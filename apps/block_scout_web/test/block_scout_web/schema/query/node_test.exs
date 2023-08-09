defmodule BlockScoutWeb.Schema.Query.NodeTest do
  use BlockScoutWeb.ConnCase

  describe "node field" do
    test "with valid argument 'id' for a transaction", %{conn: conn} do
      transaction = insert(:transaction)

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on Transaction {
            id
            hash
          }
        }
      }
      """

      id = Base.encode64("Transaction:#{transaction.hash}")

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "node" => %{
                   "id" => id,
                   "hash" => to_string(transaction.hash)
                 }
               }
             }
    end

    test "with 'id' for non-existent transaction", %{conn: conn} do
      transaction = build(:transaction)

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on Transaction {
            id
            hash
          }
        }
      }
      """

      id = Base.encode64("Transaction:#{transaction.hash}")

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      %{"errors" => [error]} = json_response(conn, 200)

      assert error["message"] == "Transaction not found."
    end

    test "with valid argument 'id' for an internal transaction", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      internal_transaction =
        insert(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_hash: transaction.block_hash,
          block_index: 0
        )

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on InternalTransaction {
            id
            transaction_hash
            index
          }
        }
      }
      """

      id =
        %{transaction_hash: to_string(transaction.hash), index: internal_transaction.index}
        |> Jason.encode!()
        |> (fn unique_id -> "InternalTransaction:#{unique_id}" end).()
        |> Base.encode64()

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "node" => %{
                   "id" => id,
                   "transaction_hash" => to_string(transaction.hash),
                   "index" => internal_transaction.index
                 }
               }
             }
    end

    test "with 'id' for non-existent internal transaction", %{conn: conn} do
      transaction = insert(:transaction) |> with_block()

      internal_transaction =
        build(:internal_transaction,
          transaction: transaction,
          index: 0,
          block_hash: transaction.block_hash,
          block_index: 0
        )

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on InternalTransaction {
            id
            transaction_hash
            index
          }
        }
      }
      """

      id =
        %{transaction_hash: to_string(transaction.hash), index: internal_transaction.index}
        |> Jason.encode!()
        |> (fn unique_id -> "InternalTransaction:#{unique_id}" end).()
        |> Base.encode64()

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      %{"errors" => [error]} = json_response(conn, 200)

      assert error["message"] == "Internal transaction not found."
    end

    test "with valid argument 'id' for a token_transfer", %{conn: conn} do
      transaction = insert(:transaction)
      token_transfer = insert(:token_transfer, transaction: transaction)

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on TokenTransfer {
            id
            transaction_hash
            log_index
          }
        }
      }
      """

      id =
        %{transaction_hash: to_string(token_transfer.transaction_hash), log_index: token_transfer.log_index}
        |> Jason.encode!()
        |> (fn unique_id -> "TokenTransfer:#{unique_id}" end).()
        |> Base.encode64()

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "node" => %{
                   "id" => id,
                   "transaction_hash" => to_string(token_transfer.transaction_hash),
                   "log_index" => token_transfer.log_index
                 }
               }
             }
    end

    test "with id for non-existent token transfer", %{conn: conn} do
      transaction = build(:transaction)

      query = """
      query($id: ID!) {
        node(id: $id) {
          ... on TokenTransfer {
            id
            transaction_hash
            log_index
          }
        }
      }
      """

      id =
        %{transaction_hash: to_string(transaction.hash), log_index: 0}
        |> Jason.encode!()
        |> (fn unique_id -> "TokenTransfer:#{unique_id}" end).()
        |> Base.encode64()

      variables = %{"id" => id}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      %{"errors" => [error]} = json_response(conn, 200)

      assert error["message"] == "Token transfer not found."
    end
  end
end
