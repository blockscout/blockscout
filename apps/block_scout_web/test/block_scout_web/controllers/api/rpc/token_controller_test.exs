# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.RPC.TokenControllerTest do
  use BlockScoutWeb.ConnCase

  describe "gettoken" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "response includes all required fields", %{conn: conn} do
      token = insert(:token)

      params = %{
        "module" => "token",
        "action" => "getToken",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      expected_result = %{
        "name" => token.name,
        "symbol" => token.symbol,
        "totalSupply" => to_string(token.total_supply),
        "decimals" => to_string(token.decimals),
        "type" => token.type,
        "cataloged" => token.cataloged,
        "contractAddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == expected_result
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end
  end

  describe "tokenholderlist" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholderlist"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholderlist",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that has no holders", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholderlist",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == []
      assert response["status"] == "1"
      assert response["message"] == "OK"
    end

    test "returns holders ordered by balance in Etherscan format", %{conn: conn} do
      token = insert(:token)
      contract_address_hash = token.contract_address_hash

      # value above 2^63 to make sure no scientific notation leaks into the response
      big_value = Decimal.new("965208500001258757122850")

      big_holder =
        insert(:address_current_token_balance, token_contract_address_hash: contract_address_hash, value: big_value)

      middle_holder =
        insert(:address_current_token_balance,
          token_contract_address_hash: contract_address_hash,
          value: Decimal.new(3_385_700)
        )

      small_holder =
        insert(:address_current_token_balance,
          token_contract_address_hash: contract_address_hash,
          value: Decimal.new(2)
        )

      # zero balances are not holders
      insert(:address_current_token_balance, token_contract_address_hash: contract_address_hash, value: Decimal.new(0))

      # holders of other tokens are not included
      insert(:address_current_token_balance, value: Decimal.new(100))

      params = %{
        "module" => "token",
        "action" => "tokenHolderList",
        "contractaddress" => to_string(contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == [
               %{
                 "TokenHolderAddress" => to_string(big_holder.address_hash),
                 "TokenHolderQuantity" => "965208500001258757122850"
               },
               %{
                 "TokenHolderAddress" => to_string(middle_holder.address_hash),
                 "TokenHolderQuantity" => "3385700"
               },
               %{
                 "TokenHolderAddress" => to_string(small_holder.address_hash),
                 "TokenHolderQuantity" => "2"
               }
             ]

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenholderlist_schema(), response)
    end

    test "supports page and offset pagination", %{conn: conn} do
      token = insert(:token)
      contract_address_hash = token.contract_address_hash

      holders =
        for value <- [300, 200, 100] do
          insert(:address_current_token_balance,
            token_contract_address_hash: contract_address_hash,
            value: Decimal.new(value)
          )
        end

      [first_holder, second_holder, third_holder] = holders

      base_params = %{
        "module" => "token",
        "action" => "tokenholderlist",
        "contractaddress" => to_string(contract_address_hash)
      }

      assert first_page =
               conn
               |> get("/api", Map.merge(base_params, %{"page" => "1", "offset" => "2"}))
               |> json_response(200)

      assert Enum.map(first_page["result"], & &1["TokenHolderAddress"]) == [
               to_string(first_holder.address_hash),
               to_string(second_holder.address_hash)
             ]

      assert second_page =
               conn
               |> get("/api", Map.merge(base_params, %{"page" => "2", "offset" => "2"}))
               |> json_response(200)

      assert Enum.map(second_page["result"], & &1["TokenHolderAddress"]) == [
               to_string(third_holder.address_hash)
             ]

      assert invalid_paging =
               conn
               |> get("/api", Map.merge(base_params, %{"page" => "0", "offset" => "abc"}))
               |> json_response(200)

      assert length(invalid_paging["result"]) == 3
    end
  end

  describe "tokenholdercount" do
    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokenholdercount",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "returns the holder count as a string", %{conn: conn} do
      token = insert(:token, holder_count: 30_506)

      params = %{
        "module" => "token",
        "action" => "tokenHolderCount",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["result"] == "30506"
      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokenholdercount_schema(), response)
    end

    test "returns 0 when the holder count is unknown or negative", %{conn: conn} do
      for holder_count <- [nil, -1] do
        token = insert(:token, holder_count: holder_count)

        params = %{
          "module" => "token",
          "action" => "tokenholdercount",
          "contractaddress" => to_string(token.contract_address_hash)
        }

        assert response =
                 conn
                 |> get("/api", params)
                 |> json_response(200)

        assert response["result"] == "0"
        assert response["status"] == "1"
      end
    end
  end

  describe "tokeninfo" do
    setup do
      # `Explorer.Chain.Token.FiatValue` loads as `nil` unless the market token fetcher is enabled
      initial_value = :persistent_term.get(:market_token_fetcher_enabled, false)
      :persistent_term.put(:market_token_fetcher_enabled, true)

      on_exit(fn ->
        :persistent_term.put(:market_token_fetcher_enabled, initial_value)
      end)
    end

    test "with missing contract address", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokeninfo"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "contract address is required"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with an invalid contract address hash", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokeninfo",
        "contractaddress" => "badhash"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Invalid contract address hash"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "with a contract address that doesn't exist", %{conn: conn} do
      params = %{
        "module" => "token",
        "action" => "tokeninfo",
        "contractaddress" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert response["message"] =~ "Contract address not found"
      assert response["status"] == "0"
      assert Map.has_key?(response, "result")
      refute response["result"]
    end

    test "response includes all Etherscan fields", %{conn: conn} do
      token =
        insert(:token,
          name: "Gods Unchained Cards",
          symbol: "CARD",
          type: "ERC-721",
          decimals: 0,
          total_supply: 6_972_003,
          is_verified_via_admin_panel: true,
          fiat_value: Decimal.new("10.1"),
          icon_url: "https://example.com/card.png"
        )

      params = %{
        "module" => "token",
        "action" => "tokenInfo",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert [token_info] = response["result"]

      assert token_info == %{
               "contractAddress" => to_string(token.contract_address_hash),
               "tokenName" => "Gods Unchained Cards",
               "symbol" => "CARD",
               "divisor" => "0",
               "tokenType" => "ERC721",
               "totalSupply" => "6972003",
               "blueCheckmark" => "true",
               "description" => "",
               "website" => "",
               "email" => "",
               "blog" => "",
               "reddit" => "",
               "slack" => "",
               "facebook" => "",
               "twitter" => "",
               "bitcointalk" => "",
               "github" => "",
               "telegram" => "",
               "wechat" => "",
               "linkedin" => "",
               "discord" => "",
               "whitepaper" => "",
               "tokenPriceUSD" => "10.100000000000000000",
               "image" => "https://example.com/card.png"
             }

      assert response["status"] == "1"
      assert response["message"] == "OK"
      assert :ok = ExJsonSchema.Validator.validate(tokeninfo_schema(), response)
    end

    test "falls back to empty values when token data is missing", %{conn: conn} do
      token =
        insert(:token,
          name: nil,
          symbol: nil,
          type: "ERC-1155",
          decimals: nil,
          total_supply: nil,
          is_verified_via_admin_panel: nil,
          fiat_value: nil,
          icon_url: nil
        )

      params = %{
        "module" => "token",
        "action" => "tokeninfo",
        "contractaddress" => to_string(token.contract_address_hash)
      }

      assert response =
               conn
               |> get("/api", params)
               |> json_response(200)

      assert [token_info] = response["result"]

      assert token_info["tokenName"] == ""
      assert token_info["symbol"] == ""
      assert token_info["divisor"] == ""
      assert token_info["tokenType"] == "ERC1155"
      assert token_info["totalSupply"] == ""
      assert token_info["blueCheckmark"] == "false"
      assert token_info["tokenPriceUSD"] == "0.000000000000000000"
      assert token_info["image"] == ""
      assert :ok = ExJsonSchema.Validator.validate(tokeninfo_schema(), response)
    end
  end

  defp tokenholderlist_schema do
    resolve_schema(%{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "required" => ["TokenHolderAddress", "TokenHolderQuantity"],
        "additionalProperties" => false,
        "properties" => %{
          "TokenHolderAddress" => %{"type" => "string"},
          "TokenHolderQuantity" => %{"type" => "string"}
        }
      }
    })
  end

  defp tokenholdercount_schema do
    resolve_schema(%{"type" => "string"})
  end

  @tokeninfo_fields ~w(contractAddress tokenName symbol divisor tokenType totalSupply blueCheckmark description website
    email blog reddit slack facebook twitter bitcointalk github telegram wechat linkedin discord whitepaper tokenPriceUSD
    image)

  defp tokeninfo_schema do
    resolve_schema(%{
      "type" => "array",
      "minItems" => 1,
      "maxItems" => 1,
      "items" => %{
        "type" => "object",
        "required" => @tokeninfo_fields,
        "additionalProperties" => false,
        "properties" => Map.new(@tokeninfo_fields, &{&1, %{"type" => "string"}})
      }
    })
  end

  defp resolve_schema(result) do
    %{
      "type" => "object",
      "properties" => %{
        "message" => %{"type" => "string"},
        "status" => %{"type" => "string"}
      }
    }
    |> put_in(["properties", "result"], result)
    |> ExJsonSchema.Schema.resolve()
  end
end
