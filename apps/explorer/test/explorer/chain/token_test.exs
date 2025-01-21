defmodule Explorer.Chain.TokenTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.{Address, Token}
  alias Explorer.Repo

  describe "cataloged_tokens/0" do
    test "filters only cataloged tokens" do
      {:ok, date} = DateTime.now("Etc/UTC")
      hours_ago_date = DateTime.add(date, -:timer.hours(60), :millisecond)
      token = insert(:token, cataloged: true, metadata_updated_at: hours_ago_date)
      insert(:token, cataloged: false)

      [token_from_db] = Repo.all(Token.cataloged_tokens())

      assert token_from_db.contract_address_hash == token.contract_address_hash
    end

    test "filters cataloged tokens with nil metadata_updated_at" do
      token = insert(:token, cataloged: true, metadata_updated_at: nil)

      [token_from_db] = Repo.all(Token.cataloged_tokens())

      assert token_from_db.contract_address_hash == token.contract_address_hash
    end

    test "filter tokens by metadata_updated_at field" do
      {:ok, date} = DateTime.now("Etc/UTC")
      hours_ago_date = DateTime.add(date, -:timer.hours(60), :millisecond)

      token = insert(:token, cataloged: true, metadata_updated_at: hours_ago_date)

      [token_from_db] = Repo.all(Token.cataloged_tokens())

      assert token_from_db.contract_address_hash == token.contract_address_hash
    end
  end

  describe "stream_cataloged_tokens/2" do
    test "reduces with given reducer and accumulator" do
      today = DateTime.utc_now()
      yesterday = Timex.shift(today, days: -1)
      token = insert(:token, cataloged: true, metadata_updated_at: yesterday)
      insert(:token, cataloged: false)
      {:ok, [token_from_func]} = Token.stream_cataloged_tokens([], &[&1 | &2], 1)
      assert token_from_func.contract_address_hash == token.contract_address_hash
    end

    test "sorts the tokens by metadata_updated_at in ascending order" do
      today = DateTime.utc_now()
      yesterday = Timex.shift(today, days: -1)
      two_days_ago = Timex.shift(today, days: -2)

      token1 = insert(:token, %{cataloged: true, metadata_updated_at: yesterday})
      token2 = insert(:token, %{cataloged: true, metadata_updated_at: two_days_ago})

      expected_response =
        [token1, token2]
        |> Enum.sort(&(Timex.to_unix(&1.metadata_updated_at) < Timex.to_unix(&2.metadata_updated_at)))
        |> Enum.map(& &1.contract_address_hash)

      {:ok, response} = Token.stream_cataloged_tokens([], &(&2 ++ [&1]), 12)

      formatted_response =
        response
        |> Enum.sort(&(Timex.to_unix(&1.metadata_updated_at) < Timex.to_unix(&2.metadata_updated_at)))
        |> Enum.map(& &1.contract_address_hash)

      assert formatted_response == expected_response
    end
  end

  describe "update/2" do
    test "updates a token's values" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: Decimal.new(1),
        cataloged: true
      }

      assert {:ok, updated_token} = Token.update(token, update_params)
      assert updated_token.name == update_params.name
      assert updated_token.symbol == update_params.symbol
      assert updated_token.total_supply == Decimal.new(update_params.total_supply)
      assert updated_token.decimals == update_params.decimals
      assert updated_token.cataloged
    end

    test "trims names of whitespace" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "      Hodl Token     ",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      assert {:ok, updated_token} = Token.update(token, update_params)
      assert updated_token.name == "Hodl Token"
      assert Repo.get_by(Address.Name, name: "Hodl Token")
    end

    test "inserts an address name record when token has a name in params" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1,
        cataloged: true
      }

      Token.update(token, update_params)
      assert Repo.get_by(Address.Name, name: update_params.name, address_hash: token.contract_address_hash)
    end

    test "does not insert address name record when token doesn't have name in params" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        cataloged: true
      }

      Token.update(token, update_params)
      refute Repo.get_by(Address.Name, address_hash: token.contract_address_hash)
    end

    test "stores token with big 'decimals' values" do
      token = insert(:token, name: nil, symbol: nil, total_supply: nil, decimals: nil, cataloged: false)

      update_params = %{
        name: "Hodl Token",
        symbol: "HT",
        total_supply: 10,
        decimals: 1_000_000_000_000_000_000,
        cataloged: true
      }

      assert {:ok, _updated_token} = Token.update(token, update_params)
    end
  end
end
