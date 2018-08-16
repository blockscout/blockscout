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
end
