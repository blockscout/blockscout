defmodule BlockScoutWeb.ViewingTokensTest do
  use BlockScoutWeb.FeatureCase, async: true

  alias BlockScoutWeb.TokenPage

  describe "viewing token holders" do
    test "list the token holders", %{session: session} do
      token = insert(:token)

      insert_list(
        2,
        :address_current_token_balance,
        token_contract_address_hash: token.contract_address_hash
      )

      session
      |> TokenPage.visit_page(token.contract_address)
      |> assert_has(TokenPage.token_holders(count: 2))
    end
  end
end
