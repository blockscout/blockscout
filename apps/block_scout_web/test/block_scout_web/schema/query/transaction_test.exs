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
                   "v" => transaction.v,
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
      assert error["message"] =~ ~s(Transaction hash #{transaction.hash} was not found)
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

      assert %{"errors" => [error]} = json_response(conn, 400)
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

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["message"] =~ ~s(Argument "hash" has invalid value)
    end
  end
end
