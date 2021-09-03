# credo:disable-for-this-file
defmodule Indexer.Celo.Util do
  @moduledoc "Runtime helper methods for concurrency tuning"

  def set_internal_transaction_batch_size(size) do
    internal_transaction_fetcher_pid()
    |> :sys.replace_state(fn state ->
      %{state | max_batch_size: size}
    end)
  end

  def set_internal_transaction_concurrency(size) do
    internal_transaction_fetcher_pid()
    |> :sys.replace_state(fn state ->
      %{state | max_concurrency: size}
    end)
  end

  def get_internal_transaction_state() do
    internal_transaction_fetcher_pid()
    |> :sys.get_state()
  end

  defp internal_transaction_fetcher_pid do
    {_child_id, pid, _, _} =
      Supervisor.which_children(Indexer.Fetcher.InternalTransaction.Supervisor)
      |> Enum.find(fn
        {Indexer.Fetcher.InternalTransaction, _, _, _} -> true
        _ -> false
      end)

    pid
  end
end
