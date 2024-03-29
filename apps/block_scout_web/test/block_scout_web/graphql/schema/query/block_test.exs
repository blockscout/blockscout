defmodule BlockScoutWeb.GraphQL.Schema.Query.BlockTest do
  use BlockScoutWeb.ConnCase

  describe "block field" do
    test "with valid argument 'number', returns all expected fields", %{conn: conn} do
      block = insert(:block)

      query = """
      query ($number: Int!) {
        block(number: $number) {
          hash
          consensus
          difficulty
          gas_limit
          gas_used
          nonce
          number
          size
          timestamp
          total_difficulty
          miner_hash
          parent_hash
          parent_hash
        }
      }
      """

      variables = %{"number" => block.number}

      conn = post(conn, "/api/v1/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "block" => %{
                   "hash" => to_string(block.hash),
                   "consensus" => block.consensus,
                   "difficulty" => to_string(block.difficulty),
                   "gas_limit" => to_string(block.gas_limit),
                   "gas_used" => to_string(block.gas_used),
                   "nonce" => to_string(block.nonce),
                   "number" => block.number,
                   "size" => block.size,
                   "timestamp" => DateTime.to_iso8601(block.timestamp),
                   "total_difficulty" => to_string(block.total_difficulty),
                   "miner_hash" => to_string(block.miner_hash),
                   "parent_hash" => to_string(block.parent_hash)
                 }
               }
             }
    end

    test "errors for non-existent block number", %{conn: conn} do
      block = insert(:block)
      non_existent_block_number = block.number + 1

      query = """
      query ($number: Int!) {
        block(number: $number) {
          number
        }
      }
      """

      variables = %{"number" => non_existent_block_number}

      conn = post(conn, "/api/v1/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Block number #{non_existent_block_number} was not found)
    end

    test "errors if argument 'number' is missing", %{conn: conn} do
      insert(:block)

      query = """
      {
        block {
          number
        }
      }
      """

      conn = get(conn, "/api/v1/graphql", query: query)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] == ~s(In argument "number": Expected type "Int!", found null.)
    end

    test "errors if argument 'number' is not an integer", %{conn: conn} do
      insert(:block)

      query = """
      query ($number: Int!) {
        block(number: $number) {
          number
        }
      }
      """

      variables = %{"number" => "invalid"}

      conn = get(conn, "/api/v1/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Argument "number" has invalid value)
    end
  end
end
