defmodule Indexer.Prometheus.Collector.PendingTransactionOperations do
  @moduledoc """
  Custom collector to count number of records in pending_transaction_operations table.
  """

  use Prometheus.Collector

  alias Explorer.Chain.PendingTransactionOperation
  alias Explorer.Repo
  alias Prometheus.Model

  def collect_mf(_registry, callback) do
    callback.(
      create_gauge(
        :pending_transaction_operations_count,
        "Number of records in pending_transaction_operations table",
        Repo.aggregate(PendingTransactionOperation, :count)
      )
    )
  end

  def collect_metrics(:pending_transaction_operations_count, count) do
    Model.gauge_metrics([{count}])
  end

  defp create_gauge(name, help, data) do
    Model.create_mf(name, help, :gauge, __MODULE__, data)
  end
end
