defmodule BlockScoutWeb.Chain.TransactionHistoryChartController do
  use BlockScoutWeb, :controller

  alias Explorer.Chain.Transaction.History.TransactionStats

  def show(conn, _params) do
    with true <- ajax?(conn) do
      [{:history_size, history_size}]  = Application.get_env(:block_scout_web, __MODULE__, 30)

      latest = Date.utc_today()
      earliest = Date.add(latest, -1 * history_size)

      transaction_history_data = TransactionStats.by_date_range(earliest, latest)
      |> extract_history
      |> encode_transaction_history_data

      json(conn, %{
        history_data: transaction_history_data,
      })
    else
      _ -> unprocessable_entity(conn)
    end
  end

  defp extract_history(db_results) do
    Enum.map(db_results, fn row ->
      %{date: row.date, number_of_transactions: row.number_of_transactions} end)
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
