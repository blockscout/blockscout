defmodule Indexer.Wobserver.BufferedTask do
  alias Indexer.BalanceFetcher

  @table Indexer.Wobserver.Metrics

  def attach_to_telemetry do
    Telemetry.attach(__MODULE__, [:indexer, :buffered_task, :current_buffer_length, :increment], __MODULE__, :handle_event)
    Telemetry.attach(__MODULE__, [:indexer, :buffered_task, :current_buffer_length, :reset], __MODULE__, :handle_event)
  end

  def handle_event([:indexer, :buffered_task, :current_buffer, :grow], count, %{name: name}, _config) do
    increment_current_buffer_length(@table, name, count)
  end

  def handle_event([:indexer, :buffered_task, :current_buffer, :reset], 0, %{name: name}, _config) do
    reset_current_buffer_length(@table, name)
  end

  def increment_current_buffer_length(table, callback_module, count) do
    :ets.update_counter(table, {Indexer.BufferedTask, callback_module, :current_buffer_length}, count, 0)
  end

  def reset_current_buffer_length(table, callback_module) do
    :ets.update_element(table, {Indexer.BufferedTask, callback_module, :current_buffer_length}, {2, 0})
  end

  def current_buffer_length(table, callback_module) do
    :ets.lookup(@table, {Indexer.BufferedTask, callback_module, :current_buffer_length})
  end

  def page(callback_module) do
    buffer_size = current_buffer_length(@table, callback_module)

    %{title(callback_module) => %{"Buffer Size" => buffer_size, "Queued Batch Count" => queue_batch_count, "Queue Size" => queue_size, "Task Count" => task_count}}
  end

  defp title(BalanceFetcher), do: "Balance Fetcher"
  defp title(InternalTransactionFetcher), do: "Internal Transaction Fetcher"
end
