# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.TokenViewTest do
  use BlockScoutWeb.ConnCase, async: true

  alias BlockScoutWeb.API.V2.TokenView

  describe "exchange_rate/1" do
    test "returns string when fiat_value exists" do
      assert TokenView.exchange_rate(%{fiat_value: Decimal.new("1.5")}) == "1.5"
    end

    test "returns nil when fiat_value is nil" do
      assert TokenView.exchange_rate(%{fiat_value: nil}) == nil
    end
  end

  describe "render token.json" do
    test "renders token fields" do
      token = insert(:token)
      result = TokenView.render("token.json", %{token: token})

      assert result["symbol"] == token.symbol
      assert result["name"] == token.name
      assert result["type"] == token.type
      assert result["decimals"] == token.decimals
      assert Map.has_key?(result, "address_hash")
      assert Map.has_key?(result, "holders_count")
    end

    test "returns nil for nil token" do
      assert TokenView.render("token.json", %{token: nil}) == nil
    end
  end

  describe "prepare_token_instance/2" do
    test "includes image_media_type and animation_media_type fields" do
      token = insert(:token, type: "ERC-721")

      instance =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: "image/png",
          animation_type: "video/mp4"
        )

      result = TokenView.prepare_token_instance(instance, token)

      assert result["image_media_type"] == "image"
      assert result["animation_media_type"] == "video"
    end

    test "returns nil for media categories when types are nil" do
      token = insert(:token, type: "ERC-721")

      instance =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: nil,
          animation_type: nil
        )

      result = TokenView.prepare_token_instance(instance, token)

      assert result["image_media_type"] == nil
      assert result["animation_media_type"] == nil
    end

    test "returns nil for media categories when types are empty strings" do
      token = insert(:token, type: "ERC-721")

      instance =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: "",
          animation_type: ""
        )

      result = TokenView.prepare_token_instance(instance, token)

      assert result["image_media_type"] == nil
      assert result["animation_media_type"] == nil
    end

    test "maps text/html to html category" do
      token = insert(:token, type: "ERC-721")

      instance =
        insert(:token_instance,
          token_contract_address_hash: token.contract_address_hash,
          metadata: %{"image" => "https://example.com/img.png"},
          image_type: "text/html",
          animation_type: ""
        )

      result = TokenView.prepare_token_instance(instance, token)

      assert result["image_media_type"] == "html"
      assert result["animation_media_type"] == nil
    end
  end
end
