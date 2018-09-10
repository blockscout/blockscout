if Code.ensure_loaded(Wobserver) == {:module, Wobserver} do
  defmodule Indexer.Wobserver do
    alias Indexer.{BalanceFetcher, BufferedTask, InternalTransactionFetcher, PendingTransactionFetcher}

    def attach_to_telemetry do
      :ets.new(Indexer.Wobserver.Metrics, [:set, :public, :named_table, {:read_concurrency, true}])

      Indexer.Wobserver.BlockFetcher.Realtime.attach_to_telemetry()
      Indexer.Wobserver.BufferedTask.attach_to_telemetry()
    end

    def metrics do
      %{}
      |> Map.merge(Indexer.Wobserver.BufferedTask.metrics(BalanceFetcher))
      |> Map.merge(Indexer.Wobserver.BlockFetcher.Realtime.metrics())
      |> Map.merge(Indexer.Wobserver.BufferedTask.metrics(InternalTransactionFetcher))
      |> Map.merge(Indexer.Wobserver.PendingTransactionFetcher.metrics())
    end

    def page do
      %{}
      |> Map.merge(Indexer.Wobserver.BufferedTask.page(BalanceFetcher))
      |> Map.merge(Indexer.Wobserver.BlockFetcher.Realtime.page())
      |> Map.merge(Indexer.Wobserver.BufferedTask.page(InternalTransactionFetcher))
      |> Map.merge(Indexer.Wobserver.PendingTransactionFetcher.page())
    end

    def register do
      Wobserver.register(:page, {"Indexer", :indexer, &page/0})
      Wobserver.register(:metric, &metrics/0)
    end

    defp put_balance_fetcher_card(page) do
      put_buffered_task_card(page, %{name: BalanceFetcher, title: "Balance Fetcher"})
    end

    defp put_balance_fetcher_metrics(metrics) do
      %{buffer_guage: buffer_length, task_guage: task_count} = BufferedTask.metrics(BalanceFetcher)

      Map.merge(
        metrics,
        %{
          indexer_balance_fetcher_buffer_length: {buffer_length, :guage, "Balance Fetcher buffer length."},
          indexer_balance_fetcher_task_count: {task_count, :guage, "Balance Fetcher task count."}
        }
      )
    end

    defp put_internal_transaction_fetcher_card(page) do
      put_buffered_task_card(page, %{name: InternalTransactionFetcher, title: "Internal Transaction Fetcher"})
    end

    defp put_internal_transaction_fetcher_metrics(metrics) do
      %{buffer_guage: indexer_balance_fetcher_buffer, task_guage: indexer_balance_fetcher_task} =
        BufferedTask.metrics(InternalTransactionFetcher)

      Map.merge(
        metrics,
        %{
          indexer_internal_transaction_fetcher_buffer:
            {indexer_balance_fetcher_buffer, :guage, "Internal Transaction Fetcher buffer length."},
          indexer_internal_transaction_fetcher_task:
            {indexer_balance_fetcher_task, :guage, "Internal Transaction Fetcher task count."}
        }
      )
    end

    defp put_pending_transaction_fetcher_card(page) do
      %{countdown: countdown, status: status} = PendingTransactionFetcher.metrics()

      Map.put(page, "Pending Transaction Fetcher", %{
        "Time until next fetch (ms)" => countdown,
        "Status" => status
      })
    end

    defp put_pending_transaction_fetcher_metrics(metrics) do
      %{countdown: countdown} = PendingTransactionFetcher.metrics()

      Map.merge(metrics, %{
        indexer_pending_transaction_fetcher_countdown:
          {countdown, :guage, "Time until next pending transaction fetch (ms)"}
      })
    end

    defp put_buffered_task_card(page, %{name: name, title: title}) do
      %{buffer_guage: buffer_size, task_guage: task_count} = BufferedTask.metrics(name)

      Map.put(page, title, %{"Buffer Size" => buffer_size, "Task Count" => task_count})
    end
  end
end
