defmodule Explorer.Chain.TokenTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain

  describe "cataloged_tokens/0" do
    test "filters only cataloged tokens" do
      token = insert(:token, cataloged: true)
      insert(:token, cataloged: false)

      assert Repo.all(Chain.Token.cataloged_tokens()) == [token.contract_address_hash]
    end
  end
end
