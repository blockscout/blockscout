defmodule BlockScoutWeb.Api.V2.Ethereum.DepositControllerTest do
  use BlockScoutWeb.ConnCase
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Repo

  if @chain_type == :ethereum do
    describe "/beacon/deposits" do
      test "get empty list when no deposits exist", %{conn: conn} do
        request = get(conn, "/api/v2/beacon/deposits")
        assert response = json_response(request, 200)
        assert %{"items" => []} = response
      end

      test "get deposits", %{conn: conn} do
        deposits = insert_list(51, :beacon_deposit)

        request = get(conn, "/api/v2/beacon/deposits")
        assert response = json_response(request, 200)
        assert %{"items" => deposits_json, "next_page_params" => next_page_params} = response
        request_2nd_page = get(conn, "/api/v2/beacon/deposits", next_page_params)
        assert response_2nd_page = json_response(request_2nd_page, 200)
        assert %{"items" => deposits_json_2nd_page} = response_2nd_page

        assert deposits_json
               |> Kernel.++(deposits_json_2nd_page)
               |> Enum.map(&{&1["index"], &1["transaction_hash"], &1["block_hash"]}) ==
                 deposits
                 |> Enum.reverse()
                 |> Enum.map(&{&1.index, to_string(&1.transaction_hash), to_string(&1.block_hash)})
      end
    end

    describe "/beacon/deposits/count" do
      test "returns 0 when no deposits exist", %{conn: conn} do
        request = get(conn, "/api/v2/beacon/deposits/count")
        assert response = json_response(request, 200)
        assert %{"deposits_count" => 0} = response
      end

      test "returns deposit count", %{conn: conn} do
        Repo.delete_all(Explorer.Chain.Beacon.Deposit)
        ExMachina.Sequence.reset("beacon_deposit_index")

        insert_list(3, :beacon_deposit)

        deposits_count = Repo.aggregate(Explorer.Chain.Beacon.Deposit, :count, :index)

        request = get(conn, "/api/v2/beacon/deposits/count")
        assert response = json_response(request, 200)
        assert %{"deposits_count" => ^deposits_count} = response
      end
    end
  end
end
