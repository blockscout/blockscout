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
      latest = Date.utc_today()
      dts = [latest, Date.add(latest, -1), Date.add(latest, -2)]

      some_transaction_stats = [
        %{date: Enum.at(dts, 1), number_of_transactions: 20},
        %{date: Enum.at(dts, 2), number_of_transactions: 30}
      ]

      {num, _} = Repo.insert_all(TransactionStats, some_transaction_stats)
      assert num == 2

      conn =
        build_conn()
        |> put_req_header("x-requested-with", "xmlhttprequest")
        |> TransactionHistoryChartController.show([])

      # turn conn.resp_body into a map using JSON
      response_data = Jason.decode!(conn.resp_body, keys: :atoms)
      history_data = Jason.decode!(response_data.history_data, keys: :atoms)

      history_data_with_elixir_dates =
        Enum.map(history_data, fn stat ->
          Map.put(stat, :date, Date.from_iso8601!(stat.date))
        end)

      assert history_data_with_elixir_dates == some_transaction_stats
    end
  end
end
