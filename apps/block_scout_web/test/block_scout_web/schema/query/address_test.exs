defmodule BlockScoutWeb.Schema.Query.AddressTest do
  use BlockScoutWeb.ConnCase

  describe "address field" do
    test "with valid argument 'hashes', returns all expected fields", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)

      query = """
      query ($hashes: [AddressHash!]!) {
        addresses(hashes: $hashes) {
          hash
          fetched_coin_balance
          fetched_coin_balance_block_number
          contract_code
        }
      }
      """

      variables = %{"hashes" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "addresses" => [
                   %{
                     "hash" => to_string(address.hash),
                     "fetched_coin_balance" => to_string(address.fetched_coin_balance.value),
                     "fetched_coin_balance_block_number" => address.fetched_coin_balance_block_number,
                     "contract_code" => nil
                   }
                 ]
               }
             }
    end

    test "with contract address, `contract_code` is serialized as expected", %{conn: conn} do
      address = insert(:contract_address, fetched_coin_balance: 100)

      query = """
      query ($hashes: [AddressHash!]!) {
        addresses(hashes: $hashes) {
          contract_code
        }
      }
      """

      variables = %{"hashes" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "addresses" => [
                   %{
                     "contract_code" => to_string(address.contract_code)
                   }
                 ]
               }
             }
    end

    test "errors for non-existent address hashes", %{conn: conn} do
      address = build(:address)

      query = """
      query ($hashes: [AddressHash!]!) {
        addresses(hashes: $hashes) {
          fetched_coin_balance
        }
      }
      """

      variables = %{"hashes" => [to_string(address.hash)]}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Addresses not found.)
    end

    test "errors if argument 'hashes' is missing", %{conn: conn} do
      query = """
      query {
        addresses {
          fetched_coin_balance
        }
      }
      """

      variables = %{}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] == ~s(In argument "hashes": Expected type "[AddressHash!]!", found null.)
    end

    test "errors if argument 'hashes' is not a list of address hashes", %{conn: conn} do
      query = """
      query ($hashes: [AddressHash!]!) {
        addresses(hashes: $hashes) {
          fetched_coin_balance
        }
      }
      """

      variables = %{"hashes" => ["someInvalidHash"]}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Argument "hashes" has invalid value)
    end

    test "correlates complexity to size of 'hashes' argument", %{conn: conn} do
      # max of 12 addresses with four fields of complexity 1 can be fetched
      # per query:
      # 12 * 4 = 48, which is less than a max complexity of 50
      hashes = 13 |> build_list(:address) |> Enum.map(&to_string(&1.hash))

      query = """
      query ($hashes: [AddressHash!]!) {
        addresses(hashes: $hashes) {
          hash
          fetched_coin_balance
          fetched_coin_balance_block_number
          contract_code
        }
      }
      """

      variables = %{"hashes" => hashes}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error1, error2]} = json_response(conn, 200)
      assert error1["message"] =~ ~s(Field addresses is too complex)
      assert error2["message"] =~ ~s(Operation is too complex)
    end
  end
end
