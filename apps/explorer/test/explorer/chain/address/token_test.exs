defmodule Explorer.Chain.Address.TokenTest do
  use Explorer.DataCase

  alias Explorer.Repo
  alias Explorer.Chain.Address
  alias Explorer.Chain.Token
  alias Explorer.PagingOptions

  describe "list_address_tokens_with_balance/2" do
    test "returns tokens with number of transfers and balance value attached" do
      address = insert(:address)

      token =
        :token
        |> insert(name: "token-c", type: "ERC-721", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      fetched_token =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> List.first()

      assert fetched_token == %Explorer.Chain.Address.Token{
               contract_address_hash: token.contract_address_hash,
               inserted_at: token.inserted_at,
               name: "token-c",
               symbol: "TC",
               balance: Decimal.new(1000),
               decimals: Decimal.new(0),
               type: "ERC-721"
             }
    end

    test "returns tokens ordered by type in reverse alphabetical order" do
      address = insert(:address)

      token =
        :token
        |> insert(name: nil, type: "ERC-721", decimals: nil, symbol: nil)
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      token2 =
        :token
        |> insert(name: "token-c", type: "ERC-20", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token2.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token2.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      fetched_tokens =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> Enum.map(& &1.contract_address_hash)

      assert fetched_tokens == [token.contract_address_hash, token2.contract_address_hash]
    end

    test "returns tokens of same type by name in lowercase ascending" do
      address = insert(:address)

      token =
        :token
        |> insert(name: "atoken", type: "ERC-721", decimals: nil, symbol: nil)
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      token2 =
        :token
        |> insert(name: "1token-c", type: "ERC-721", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token2.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token2.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      token3 =
        :token
        |> insert(name: "token-c", type: "ERC-721", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token3.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token3.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      fetched_tokens =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> Enum.map(& &1.contract_address_hash)

      assert fetched_tokens == [token2.contract_address_hash, token.contract_address_hash, token3.contract_address_hash]
    end

    test "returns tokens with null name after all the others of same type" do
      address = insert(:address)

      token =
        :token
        |> insert(name: nil, type: "ERC-721", decimals: nil, symbol: nil)
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      token2 =
        :token
        |> insert(name: "token-c", type: "ERC-721", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token2.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token2.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      token3 =
        :token
        |> insert(name: "token-c", type: "ERC-721", decimals: 0, symbol: "TC")
        |> Repo.preload(:contract_address)

      insert(
        :address_current_token_balance,
        address: address,
        token_contract_address_hash: token3.contract_address_hash,
        value: 1000
      )

      insert(
        :token_transfer,
        token_contract_address: token3.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      last_fetched_token =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> Enum.map(& &1.contract_address_hash)
        |> List.last()

      assert last_fetched_token == token.contract_address_hash
    end

    test "does not return tokens with zero balance" do
      address = insert(:address)

      token =
        :token
        |> insert(name: "atoken", type: "ERC-721", decimals: 0, symbol: "AT")
        |> Repo.preload(:contract_address)

      insert(
        :token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 0
      )

      fetched_token =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> Enum.find(fn t -> t.name == "atoken" end)

      assert fetched_token == nil
    end

    test "ignores token if the last balance is zero" do
      address = insert(:address)

      token =
        :token
        |> insert(name: "atoken", type: "ERC-721", decimals: 0, symbol: "AT")
        |> Repo.preload(:contract_address)

      insert(
        :token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 1000
      )

      insert(
        :token_balance,
        address: address,
        token_contract_address_hash: token.contract_address_hash,
        value: 0
      )

      insert(
        :token_transfer,
        token_contract_address: token.contract_address,
        from_address: address,
        to_address: build(:address)
      )

      fetched_token =
        address.hash
        |> Address.Token.list_address_tokens_with_balance()
        |> Repo.all()
        |> List.first()

      assert fetched_token == nil
    end
  end

  describe "page_tokens/2" do
    test "just bring the normal query when PagingOptions.key is nil" do
      options = %PagingOptions{key: nil}

      query = Ecto.Query.from(t in Token)

      assert Address.Token.page_tokens(query, options) == query
    end

    test "add more conditions to the query when PagingOptions.key is not nil" do
      token1 = insert(:token, name: "token-a", type: "ERC-20", decimals: 0, symbol: "TA")

      token2 = insert(:token, name: "token-c", type: "ERC-721", decimals: 0, symbol: "TC")

      options = %PagingOptions{key: {token2.name, token2.type, token2.inserted_at}}

      query = Ecto.Query.from(t in Token, order_by: t.type, preload: :contract_address)

      fetched_token = hd(Repo.all(Address.Token.page_tokens(query, options)))
      refute Address.Token.page_tokens(query, options) == query
      assert fetched_token == token1
    end

    test "tokens with nil name come after other tokens of same type" do
      token1 = insert(:token, name: "token-a", type: "ERC-20", decimals: 0, symbol: "TA")

      token2 = insert(:token, name: nil, type: "ERC-20", decimals: 0, symbol: "TC")

      options = %PagingOptions{key: {token1.name, token1.type, token1.inserted_at}}

      query = Ecto.Query.from(t in Token, order_by: t.type, preload: :contract_address)

      fetched_token = hd(Repo.all(Address.Token.page_tokens(query, options)))
      assert fetched_token == token2
    end
  end
end
