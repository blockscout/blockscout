defmodule BlockScoutWeb.Tokens.OverviewViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.Tokens.OverviewView

  describe "decimals?/1" do
    test "returns true when Token has decimals" do
      token = insert(:token, decimals: 18)

      assert OverviewView.decimals?(token) == true
    end

    test "returns false when Token hasn't decimals" do
      token = insert(:token, decimals: nil)

      assert OverviewView.decimals?(token) == false
    end
  end

  describe "token_name?/1" do
    test "returns true when Token has a name" do
      token = insert(:token, name: "Some Token")

      assert OverviewView.token_name?(token) == true
    end

    test "returns false when Token hasn't a name" do
      token = insert(:token, name: nil)

      assert OverviewView.token_name?(token) == false
    end
  end

  describe "total_supply?/1" do
    test "returns true when Token has total_supply" do
      token = insert(:token, total_supply: 1_000)

      assert OverviewView.total_supply?(token) == true
    end

    test "returns false when Token hasn't total_supply" do
      token = insert(:token, total_supply: nil)

      assert OverviewView.total_supply?(token) == false
    end
  end

  describe "current_tab_name/1" do
    test "returns the correctly text for the token_transfers tab" do
      token_transfers_path = "/page/0xSom3tH1ng/token_transfers/?additional_params=blah"

      assert OverviewView.current_tab_name(token_transfers_path) == "Token Transfers"
    end

    test "returns the correctly text for the token_holders tab" do
      token_holders_path = "/page/0xSom3tH1ng/token_holders/?additional_params=blah"

      assert OverviewView.current_tab_name(token_holders_path) == "Token Holders"
    end

    test "returns the correctly text for the read_contract tab" do
      read_contract_path = "/page/0xSom3tH1ng/read_contract/?additional_params=blah"

      assert OverviewView.current_tab_name(read_contract_path) == "Read Contract"
    end
  end

  describe "display_inventory?/1" do
    test "returns true when token is unique" do
      token = insert(:token, type: "ERC-721")

      assert OverviewView.display_inventory?(token) == true
    end

    test "returns false when token is not unique" do
      token = insert(:token, type: "ERC-20")

      assert OverviewView.display_inventory?(token) == false
    end
  end
end
