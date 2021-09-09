# credo:disable-for-this-file
defmodule Indexer.Celo.Util do
  @moduledoc "Runtime helper methods for concurrency tuning"

  require Logger

  def set_internal_transaction_batch_size(size) do
    internal_transaction_fetcher_pid()
    |> :sys.replace_state(fn state ->
      Logger.info("Setting internal transaction batch size from #{state[:max_batch_size]} to #{size}")
      %{state | max_batch_size: size}
    end)
  end

  def set_internal_transaction_concurrency(size) do
    internal_transaction_fetcher_pid()
    |> :sys.replace_state(fn state ->
      Logger.info("Setting internal transaction concurrency from #{state[:max_concurrency]} to #{size}")
      %{state | max_concurrency: size}
    end)
  end

  def set_internal_transaction_timeout(timeout) do
    current = Application.get_env(:ethereum_jsonrpc, :internal_transaction_timeout)
    Logger.info("Setting debug_traceTransaction rpc timeout from #{current} to #{timeout}")
    Application.put_env(:ethereum_jsonrpc, :internal_transaction_timeout, timeout, persistent: true)
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
