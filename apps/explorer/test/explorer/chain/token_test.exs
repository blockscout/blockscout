# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.{Address, Hash, Token}
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

  describe "list_top/2" do
    test "returns market data with enabled token fetcher" do
      old_source_env = Application.get_env(:explorer, Explorer.Market.Source)
      old_fetcher_env = Application.get_env(:explorer, Explorer.Market.Fetcher.Token)

      Application.put_env(
        :explorer,
        Explorer.Market.Source,
        Keyword.merge(old_source_env, tokens_source: Explorer.Market.Source.OneCoinSource)
      )

      Application.put_env(:explorer, Explorer.Market.Fetcher.Token, Keyword.merge(old_fetcher_env, enabled: true))

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.Market.Source, old_source_env)
        Application.put_env(:explorer, Explorer.Market.Fetcher.Token, old_fetcher_env)
      end)

      start_supervised!(Explorer.Market.Fetcher.Token)
      start_supervised!(Explorer.Market)

      insert_list(10, :token)

      market_data = Token.list_top(nil)

      assert Enum.all?(market_data, fn token -> not is_nil(token.fiat_value) end)
    end

    test "ignores market data with disabled token fetcher" do
      insert_list(10, :token)

      start_supervised!(Explorer.Market)

      market_data = Token.list_top(nil)

      assert Enum.all?(market_data, fn token -> is_nil(token.fiat_value) end)
    end
  end

  describe "effective_ui_multiplier/2" do
    @one Decimal.new("1000000000000000000")
    @two Decimal.new("2000000000000000000")
    @effective_at ~U[2026-09-01 00:00:00.000000Z]

    test "is nil for a token that does not implement ERC-8056" do
      refute Token.effective_ui_multiplier(build(:token))
    end

    test "returns the current multiplier when no change is scheduled" do
      token = build(:token, ui_multiplier: @one, new_ui_multiplier: nil, ui_multiplier_effective_at: nil)

      assert Token.effective_ui_multiplier(token) == @one
    end

    test "returns the current multiplier while the scheduled change is in the future" do
      token = build(:token, ui_multiplier: @one, new_ui_multiplier: @two, ui_multiplier_effective_at: @effective_at)

      assert Token.effective_ui_multiplier(token, ~U[2026-08-31 23:59:59.999999Z]) == @one
    end

    test "returns the pending multiplier from the moment it becomes effective" do
      token = build(:token, ui_multiplier: @one, new_ui_multiplier: @two, ui_multiplier_effective_at: @effective_at)

      # the on-chain getter compares with `>=`, so the switch happens exactly at
      # `effectiveAt` and nothing has to be written to the database for it
      assert Token.effective_ui_multiplier(token, @effective_at) == @two
      assert Token.effective_ui_multiplier(token, ~U[2026-09-01 00:00:00.000001Z]) == @two
    end

    test "returns the pending multiplier when effectiveAt is the Unix epoch" do
      # `effectiveAt() == 0` means the pending multiplier is already in effect
      token =
        build(:token,
          ui_multiplier: @one,
          new_ui_multiplier: @two,
          ui_multiplier_effective_at: ~U[1970-01-01 00:00:00Z]
        )

      assert Token.effective_ui_multiplier(token) == @two
    end
  end

  describe "list_top/2 with a search filter" do
    setup do
      contract_address = insert(:contract_address, hash: "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")
      target = insert(:token, contract_address: contract_address, name: "Searched Coin", symbol: "SEARCHED")
      other = insert(:token, name: "Unrelated Coin", symbol: "UNRELATED")

      %{target: target, other: other}
    end

    test "matches the contract address hash regardless of its letter case", %{target: target} do
      for filter <- [
            "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed",
            "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            "0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED",
            "  0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed \n"
          ] do
        assert [%Token{contract_address_hash: hash}] = Token.list_top(filter)
        assert hash == target.contract_address_hash, "no match for #{inspect(filter)}"
      end
    end

    test "matches nothing for an address hash no token is deployed at" do
      assert Token.list_top("0x" <> String.duplicate("ab", 20)) == []
    end

    test "full-text searches 0x-prefixed input that is not an address hash" do
      %Token{contract_address_hash: hash} = insert(:token, name: "0xBridged Coin", symbol: "XBC")

      assert [%Token{contract_address_hash: ^hash}] = Token.list_top("0xBridged")
    end

    test "full-text searches 20-byte input instead of reading it as raw address bytes" do
      name = "Twenty Char Token AB"
      assert byte_size(name) == Hash.Address.byte_count()
      %Token{contract_address_hash: hash} = insert(:token, name: name, symbol: "TCT")

      assert [%Token{contract_address_hash: ^hash}] = Token.list_top(name)
    end

    test "full-text searches 0x-prefixed 20-byte input with surrounding whitespace" do
      name = "0xEighteen Chars ABC"
      assert byte_size(name) == Hash.Address.byte_count()
      %Token{contract_address_hash: hash} = insert(:token, name: name, symbol: "ETC")

      assert [%Token{contract_address_hash: ^hash}] = Token.list_top("  #{name} \n")
    end

    test "does not filter for blank input", %{target: target, other: other} do
      expected = Enum.sort([target.contract_address_hash, other.contract_address_hash])

      for filter <- ["", "   ", nil] do
        assert filter |> Token.list_top() |> Enum.map(& &1.contract_address_hash) |> Enum.sort() == expected
      end
    end
  end
end
