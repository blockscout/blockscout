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

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "node" => %{
                   "id" => id,
                   "hash" => to_string(transaction.hash)
                 }
               }
             }
    end
  end
end
