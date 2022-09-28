defmodule BlockScoutWeb.API.V1.TransactionHistoryChartApiController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.API.APILogger
  alias Explorer.Chain.Transaction.History.TransactionStats

  def transaction_history_chart(conn, _) do
    APILogger.log(conn)
    try do
      history_size = 30

      today = Date.utc_today()
      latest = Date.add(today, -1)
      earliest = Date.add(latest, -1 * history_size)

      date_range = TransactionStats.by_date_range(earliest, latest)

      transaction_history_data =
        date_range
        |> extract_history
        |> encode_transaction_history_data

      send_resp(conn, :ok, result(transaction_history_data))
    rescue
      e in RuntimeError -> send_resp(conn, :internal_server_error, error(e))
    end
  end

  defp result(transaction_history_data) do
    %{
      "history_data" => transaction_history_data
    }
    |> Jason.encode!()
  end

  defp error(e) do
    %{
      "error" => e
    }
    |> Jason.encode!()
  end

  defp extract_history(db_results) do
    Enum.map(db_results, fn row ->
      %{date: row.date, number_of_transactions: row.number_of_transactions}
    end)
  end

  defp encode_transaction_history_data(transaction_history_data) do
    transaction_history_data
    |> Jason.encode()
    |> case do
         {:ok, data} -> data
         _ -> []
       end
  end
end