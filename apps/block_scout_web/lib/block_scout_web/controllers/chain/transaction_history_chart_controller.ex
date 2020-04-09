defmodule BlockScoutWeb.Chain.TransactionHistoryChartController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Transaction.History.TransactionStats

  def show(conn, _params) do
    if ajax?(conn) do
      [{:history_size, history_size}] = Application.get_env(:block_scout_web, __MODULE__, 30)

      current = Date.utc_today()
      latest = Date.add(current, -1)
      earliest = Date.add(latest, -1 * history_size)

      date_range = TransactionStats.by_date_range(earliest, latest)

      transaction_history_data =
        date_range
        |> extract_history
        |> encode_transaction_history_data

      json(conn, %{
        history_data: transaction_history_data
      })
    else
      unprocessable_entity(conn)
    end
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
