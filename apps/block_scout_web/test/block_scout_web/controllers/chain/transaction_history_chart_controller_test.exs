defmodule BlockScoutWeb.Chain.TransactionHistoryChartControllerTest do
  use BlockScoutWeb.ConnCase

  alias BlockScoutWeb.Chain.TransactionHistoryChartController
  alias Explorer.Chain.Transaction.History.TransactionStats
  alias Explorer.Repo

  describe "GET show/2" do
    test "returns error when not an ajax request" do
      path = transaction_history_chart_path(BlockScoutWeb.Endpoint, :show)

      conn = get(build_conn(), path)

      assert conn.status == 422
    end

    test "returns ok when request is ajax" do
      path = transaction_history_chart_path(BlockScoutWeb.Endpoint, :show)

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> get(path)

      assert json_response(conn, 200)
    end

    test "returns appropriate json data" do
      latest = ~D[2019-07-12]
      dts = [latest, Date.add(latest, -1), Date.add(latest, -2)]

      some_transaction_stats = [
        %{date: Enum.at(dts, 0), number_of_transactions: 10},
        %{date: Enum.at(dts, 1), number_of_transactions: 20},
        %{date: Enum.at(dts, 2), number_of_transactions: 30}
      ]

      {num, _} = Repo.insert_all(TransactionStats, some_transaction_stats)
      assert num == 3

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> TransactionHistoryChartController.show([])

      expected =
        "{\"history_data\":\"[{\\\"date\\\":\\\"2019-07-12\\\",\\\"number_of_transactions\\\":10},{\\\"date\\\":\\\"2019-07-11\\\",\\\"number_of_transactions\\\":20},{\\\"date\\\":\\\"2019-07-10\\\",\\\"number_of_transactions\\\":30}]\"}"

      assert conn.resp_body =~ expected
    end
  end
end
