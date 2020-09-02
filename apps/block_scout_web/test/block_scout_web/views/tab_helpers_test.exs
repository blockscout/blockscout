defmodule BlockScoutWeb.TabHelpersTest do
  use ExUnit.Case

  alias BlockScoutWeb.TabHelpers

  doctest BlockScoutWeb.TabHelpers, import: true

  describe "tab_status/2" do
    test "returns \"active\" if the tab is active" do
      tab_name = "token-transfers"
      request_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"

      assert TabHelpers.tab_status(tab_name, request_path) == "active"
    end

    test "returns nil if the tab is not active" do
      tab_name = "internal-transactions"
      request_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"

      assert TabHelpers.tab_status(tab_name, request_path) == nil
    end
  end

  describe "tab_active?/2" do
    test "returns true if the tab name is in the path" do
      tab_name = "token-transfers"
      request_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"

      assert TabHelpers.tab_active?(tab_name, request_path)
    end

    test "matches the tab name at any path level" do
      tab_name_1 = "token-transfers"
      tab_name_2 = "tokens"
      request_path = "/page/0xSom3tH1ng/tokens/0xLuc4S/token-transfers/0xd4uMl1Gu1"

      assert TabHelpers.tab_active?(tab_name_1, request_path)
      assert TabHelpers.tab_active?(tab_name_2, request_path)
    end

    test "matches only the exact tab name to avoid ambiguity" do
      tab_name = "transactions"
      request_path_1 = "/page/0xSom3tH1ng/transactions"
      request_path_2 = "/page/0xSom3tH1ng/internal-transactions"

      assert TabHelpers.tab_active?(tab_name, request_path_1)
      refute TabHelpers.tab_active?(tab_name, request_path_2)
    end

    test "returns nil if the tab name is not in the path" do
      tab_name = "internal_transactions"
      request_path = "/page/0xSom3tH1ng/token-transfers/?additional_params=blah"

      refute TabHelpers.tab_active?(tab_name, request_path)
    end
  end
end
