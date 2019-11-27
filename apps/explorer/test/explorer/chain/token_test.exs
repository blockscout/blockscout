defmodule Explorer.Chain.TokenTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain.Token
  alias Explorer.Repo

  describe "cataloged_tokens/0" do
    test "filters only cataloged tokens" do
      {:ok, date} = DateTime.now("Etc/UTC")
      hours_ago_date = DateTime.add(date, -:timer.hours(60), :millisecond)
      token = insert(:token, cataloged: true, updated_at: hours_ago_date)
      insert(:token, cataloged: false)

      assert Repo.all(Token.cataloged_tokens()) == [token.contract_address_hash]
    end

    test "filter tokens by updated_at field" do
      {:ok, date} = DateTime.now("Etc/UTC")
      hours_ago_date = DateTime.add(date, -:timer.hours(60), :millisecond)

      token = insert(:token, cataloged: true, updated_at: hours_ago_date)
      insert(:token, cataloged: true)

      assert Repo.all(Token.cataloged_tokens()) == [token.contract_address_hash]
    end
  end
end
