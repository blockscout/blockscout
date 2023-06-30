defmodule BlockScoutWeb.Schema.Query.AddressTest do
  use BlockScoutWeb.ConnCase

  describe "address field" do
    test "with valid argument 'hash', returns all expected fields", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)

      query = """
      query ($hash: AddressHash!) {
        address(hash: $hash) {
          hash
          fetched_coin_balance
          fetched_coin_balance_block_number
          contract_code
        }
      }
      """

      variables = %{"hash" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "address" => %{
                   "hash" => to_string(address.hash),
                   "fetched_coin_balance" => to_string(address.fetched_coin_balance.value),
                   "fetched_coin_balance_block_number" => address.fetched_coin_balance_block_number,
                   "contract_code" => nil
                 }
               }
             }
    end

    test "with contract address, `contract_code` is serialized as expected", %{conn: conn} do
      address = insert(:contract_address, fetched_coin_balance: 100)

      query = """
      query ($hash: AddressHash!) {
        address(hash: $hash) {
          contract_code
        }
      }
      """

      variables = %{"hash" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "address" => %{
                   "contract_code" => to_string(address.contract_code)
                 }
               }
             }
    end

    test "smart_contract returns all expected fields", %{conn: conn} do
      address = insert(:address, fetched_coin_balance: 100)
      smart_contract = insert(:smart_contract, address_hash: address.hash, contract_code_md5: "123")

      query = """
      query ($hash: AddressHash!) {
        address(hash: $hash) {
          fetched_coin_balance
          smart_contract {
            name
            compiler_version
            optimization
            contract_source_code
            abi
            address_hash
          }
        }
      }
      """

      variables = %{"hash" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "address" => %{
                   "fetched_coin_balance" => to_string(address.fetched_coin_balance.value),
                   "smart_contract" => %{
                     "name" => smart_contract.name,
                     "compiler_version" => smart_contract.compiler_version,
                     "optimization" => smart_contract.optimization,
                     "contract_source_code" => smart_contract.contract_source_code,
                     "abi" => Jason.encode!(smart_contract.abi),
                     "address_hash" => to_string(address.hash)
                   }
                 }
               }
             }
    end

    test "errors for non-existent address hash", %{conn: conn} do
      address = build(:address)

      query = """
      query ($hash: AddressHash!) {
        address(hash: $hash) {
          fetched_coin_balance
        }
      }
      """

      variables = %{"hash" => to_string(address.hash)}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Address not found.)
    end

    test "errors if argument 'hash' is missing", %{conn: conn} do
      query = """
      query {
        address {
          fetched_coin_balance
        }
      }
      """

      variables = %{}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] == ~s(In argument "hash": Expected type "AddressHash!", found null.)
    end

    test "errors if argument 'hash' is not a valid address hash", %{conn: conn} do
      query = """
      query ($hash: AddressHash!) {
        address(hash: $hash) {
          fetched_coin_balance
        }
      }
      """

      variables = %{"hash" => "someInvalidHash"}

      conn = get(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error]} = json_response(conn, 200)
      assert error["message"] =~ ~s(Argument "hash" has invalid value)
    end
  end

  describe "address transactions field" do
    test "returns all expected transaction fields", %{conn: conn} do
      address = insert(:address)

      transaction = insert(:transaction, from_address: address)

      query = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first) {
            edges {
              node {
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
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "first" => 1
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "address" => %{
                   "transactions" => %{
                     "edges" => [
                       %{
                         "node" => %{
                           "hash" => to_string(transaction.hash),
                           "block_number" => transaction.block_number,
                           "cumulative_gas_used" => nil,
                           "error" => transaction.error,
                           "gas" => to_string(transaction.gas),
                           "gas_price" => to_string(transaction.gas_price.value),
                           "gas_used" => nil,
                           "index" => transaction.index,
                           "input" => to_string(transaction.input),
                           "nonce" => to_string(transaction.nonce),
                           "r" => to_string(transaction.r),
                           "s" => to_string(transaction.s),
                           "status" => nil,
                           "v" => to_string(transaction.v),
                           "value" => to_string(transaction.value.value),
                           "from_address_hash" => to_string(transaction.from_address_hash),
                           "to_address_hash" => to_string(transaction.to_address_hash),
                           "created_contract_address_hash" => nil
                         }
                       }
                     ]
                   }
                 }
               }
             }
    end

    test "with address with zero transactions", %{conn: conn} do
      address = insert(:address)

      query = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first) {
            edges {
              node {
                hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "first" => 1
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "address" => %{
                   "transactions" => %{
                     "edges" => []
                   }
                 }
               }
             }
    end

    test "transactions are ordered by descending block and index", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      address = insert(:address)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      query = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first) {
            edges {
              node {
                hash
                block_number
                index
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "first" => 3
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      %{
        "data" => %{
          "address" => %{
            "transactions" => %{
              "edges" => transactions
            }
          }
        }
      } = json_response(conn, 200)

      block_number_and_index_order =
        Enum.map(transactions, fn transaction ->
          {transaction["node"]["block_number"], transaction["node"]["index"]}
        end)

      assert block_number_and_index_order == Enum.sort(block_number_and_index_order, &(&1 >= &2))
      assert length(transactions) == 3
      assert Enum.all?(transactions, &(&1["node"]["block_number"] == third_block.number))
    end

    test "transactions are ordered by ascending block and index", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      address = insert(:address)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      query = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first, order: ASC) {
            edges {
              node {
                hash
                block_number
                index
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "first" => 3
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      %{
        "data" => %{
          "address" => %{
            "transactions" => %{
              "edges" => transactions
            }
          }
        }
      } = json_response(conn, 200)

      block_number_and_index_order =
        Enum.map(transactions, fn transaction ->
          {transaction["node"]["block_number"], transaction["node"]["index"]}
        end)

      assert block_number_and_index_order == Enum.sort(block_number_and_index_order, &(&1 < &2))
      assert length(transactions) == 3
      assert Enum.all?(transactions, &(&1["node"]["block_number"] == first_block.number))
    end

    test "complexity correlates to 'first' or 'last' arguments", %{conn: conn} do
      address = build(:address)

      query = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first) {
            edges {
              node {
                hash
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "first" => 67
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      assert %{"errors" => [error1, error2, error3]} = json_response(conn, 200)
      assert error1["message"] =~ ~s(Field transactions is too complex)
      assert error2["message"] =~ ~s(Field address is too complex)
      assert error3["message"] =~ ~s(Operation is too complex)
    end

    test "with 'last' and 'count' arguments", %{conn: conn} do
      # "`last: N` must always be accompanied by either a `before:` argument to
      # the query, or an explicit `count:` option to the `from_query` call.
      # Otherwise it is impossible to derive the required offset."
      # https://hexdocs.pm/absinthe_relay/Absinthe.Relay.Connection.html#from_query/4
      #
      # This test ensures support of a 'count' argument.

      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      address = insert(:address)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      query = """
      query ($hash: AddressHash!, $last: Int!, $count: Int!) {
        address(hash: $hash) {
          transactions(last: $last, count: $count) {
            edges {
              node {
                hash
                block_number
              }
            }
          }
        }
      }
      """

      variables = %{
        "hash" => to_string(address.hash),
        "last" => 3,
        "count" => 9
      }

      conn = post(conn, "/graphql", query: query, variables: variables)

      %{
        "data" => %{
          "address" => %{
            "transactions" => %{
              "edges" => transactions
            }
          }
        }
      } = json_response(conn, 200)

      assert length(transactions) == 3
      assert Enum.all?(transactions, &(&1["node"]["block_number"] == first_block.number))
    end

    test "pagination support with 'first' and 'after' arguments", %{conn: conn} do
      first_block = insert(:block)
      second_block = insert(:block)
      third_block = insert(:block)

      address = insert(:address)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(second_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(third_block)

      3
      |> insert_list(:transaction, from_address: address)
      |> with_block(first_block)

      query1 = """
      query ($hash: AddressHash!, $first: Int!) {
        address(hash: $hash) {
          transactions(first: $first) {
            page_info {
              has_next_page
              has_previous_page
            }
            edges {
              node {
                hash
                block_number
              }
              cursor
            }
          }
        }
      }
      """

      variables1 = %{
        "hash" => to_string(address.hash),
        "first" => 3
      }

      conn = post(conn, "/graphql", query: query1, variables: variables1)

      %{"data" => %{"address" => %{"transactions" => page1}}} = json_response(conn, 200)

      assert page1["page_info"] == %{"has_next_page" => true, "has_previous_page" => false}
      assert Enum.all?(page1["edges"], &(&1["node"]["block_number"] == third_block.number))

      last_cursor_page1 =
        page1
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      query2 = """
      query ($hash: AddressHash!, $first: Int!, $after: String!) {
        address(hash: $hash) {
          transactions(first: $first, after: $after) {
            page_info {
              has_next_page
              has_previous_page
            }
            edges {
              node {
                hash
                block_number
              }
              cursor
            }
          }
        }
      }
      """

      variables2 = %{
        "hash" => to_string(address.hash),
        "first" => 3,
        "after" => last_cursor_page1
      }

      conn = post(conn, "/graphql", query: query2, variables: variables2)

      %{"data" => %{"address" => %{"transactions" => page2}}} = json_response(conn, 200)

      assert page2["page_info"] == %{"has_next_page" => true, "has_previous_page" => true}
      assert Enum.all?(page2["edges"], &(&1["node"]["block_number"] == second_block.number))

      last_cursor_page2 =
        page2
        |> Map.get("edges")
        |> List.last()
        |> Map.get("cursor")

      variables3 = %{
        "hash" => to_string(address.hash),
        "first" => 3,
        "after" => last_cursor_page2
      }

      conn = post(conn, "/graphql", query: query2, variables: variables3)

      %{"data" => %{"address" => %{"transactions" => page3}}} = json_response(conn, 200)

      assert page3["page_info"] == %{"has_next_page" => false, "has_previous_page" => true}
      assert Enum.all?(page3["edges"], &(&1["node"]["block_number"] == first_block.number))
    end
  end
end
