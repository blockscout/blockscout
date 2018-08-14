defmodule BlockScoutWeb.TokenViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.TokenView

  describe "decimals?/1" do
    test "returns true when Token has decimals" do
      token = insert(:token, decimals: 18)

      assert TokenView.decimals?(token) == true
    end

    test "returns false when Token hasn't decimals" do
      token = insert(:token, decimals: nil)

      assert TokenView.decimals?(token) == false
    end
  end

  describe "token_name?/1" do
    test "returns true when Token has a name" do
      token = insert(:token, name: "Some Token")

      assert TokenView.token_name?(token) == true
    end

    test "returns false when Token hasn't a name" do
      token = insert(:token, name: nil)

      assert TokenView.token_name?(token) == false
    end
  end

  describe "total_supply?/1" do
    test "returns true when Token has total_supply" do
      token = insert(:token, total_supply: 1_000)

      assert TokenView.total_supply?(token) == true
    end

    test "returns false when Token hasn't total_supply" do
      token = insert(:token, total_supply: nil)

      assert TokenView.total_supply?(token) == false
    end
  end
end
