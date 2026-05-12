defmodule BlockScoutWeb.API.V2.ShibariumControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.Shibarium.Bridge

  if @chain_type == :shibarium do
    describe "/api/v2/shibarium/deposits" do
      test "returns empty list when no deposits exist", %{conn: conn} do
        request = get(conn, "/api/v2/shibarium/deposits")
        assert response = json_response(request, 200)

        assert response["items"] == []
        assert response["next_page_params"] == nil
      end

      test "returns deposits with next_page_params and paginates", %{conn: conn} do
        deposits = insert_list(51, :address) |> Enum.map(&insert_shibarium_deposit(&1.hash))

        request = get(conn, "/api/v2/shibarium/deposits")
        assert response = json_response(request, 200)

        assert Enum.count(response["items"]) == 50
        assert response["next_page_params"] != nil
        assert response["next_page_params"]["block_number"] != nil
        assert response["next_page_params"]["items_count"] == 50

        compare_deposit(Enum.at(deposits, 50), Enum.at(response["items"], 0))
        compare_deposit(Enum.at(deposits, 1), Enum.at(response["items"], 49))

        request_2nd_page = get(conn, "/api/v2/shibarium/deposits", response["next_page_params"])
        assert response_2nd_page = json_response(request_2nd_page, 200)
        assert Enum.count(response_2nd_page["items"]) == 1
        assert response_2nd_page["next_page_params"] == nil

        compare_deposit(Enum.at(deposits, 0), Enum.at(response_2nd_page["items"], 0))
      end

      test "renders user as Address even when no address row exists", %{conn: conn} do
        orphan_hash = address_hash()
        insert_shibarium_deposit(orphan_hash)

        request = get(conn, "/api/v2/shibarium/deposits")
        assert response = json_response(request, 200)

        [item] = response["items"]
        assert is_map(item["user"])
        assert String.downcase(item["user"]["hash"]) == String.downcase(to_string(orphan_hash))
      end

      test "rejects malformed block_number with 422", %{conn: conn} do
        request = get(conn, "/api/v2/shibarium/deposits", %{"block_number" => "not-a-number"})
        assert json_response(request, 422)
      end
    end

    defp insert_shibarium_deposit(user_hash) do
      l1_block_number = block_number()

      {:ok, bridge} =
        %Bridge{}
        |> Bridge.changeset(%{
          user: user_hash,
          operation_hash: transaction_hash(),
          operation_type: :deposit,
          token_type: :bone,
          l1_transaction_hash: transaction_hash(),
          l1_block_number: l1_block_number,
          l2_transaction_hash: transaction_hash(),
          l2_block_number: block_number(),
          timestamp: DateTime.utc_now()
        })
        |> Explorer.Repo.insert()

      bridge
    end

    defp compare_deposit(%Bridge{} = item, json) do
      assert item.l1_block_number == json["l1_block_number"]
      assert to_string(item.l1_transaction_hash) == json["l1_transaction_hash"]
      assert to_string(item.l2_transaction_hash) == json["l2_transaction_hash"]
      assert to_string(item.user) == json["user"]["hash"] |> String.downcase()
      assert DateTime.to_iso8601(item.timestamp) == json["timestamp"]
    end
  end
end
