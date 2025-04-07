defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric

  @histogram [
    name: :block_import_stage_runner_duration_microseconds,
    labels: [:stage, :runner, :step],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Block import stage, runner and step in runner processing time"
  ]

  @histogram [
    name: :media_processing_time,
    buckets: :default,
    duration_unit: :seconds,
    help: "Time in seconds taken for media resizing and uploading"
  ]

  @gauge [
    name: :success_transactions_number,
    help: "Number of successful transactions in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :deployed_smart_contracts_number,
    help:
      "Number of deployed smart-contracts (smart-contracts from internal transactions are not accounted) in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :verified_smart_contracts_number,
    help: "Number of verified smart-contracts in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :new_addresses_number,
    help: "Number of new wallet addresses in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :new_tokens_number,
    help: "Number of new tokens detected in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :new_token_transfers_number,
    help: "Number of new token transfers detected in the period (default is 1 day)",
    registry: :public
  ]

  @gauge [
    name: :active_addresses_number,
    help: "Number of active EOA addresses (participated in transactions in to/from) in the period (default is 1 day)",
    registry: :public
  ]

  @counter [
    name: :successfully_uploaded_media_number,
    help: "Number of successfully uploaded media to CDN",
    registry: :public
  ]

  @counter [
    name: :failed_uploading_media_number,
    help: "Number of failed uploading media to CDN",
    registry: :public
  ]

  @gauge [name: :batch_average_time, help: "L2 average batch time"]

  def block_import_stage_runner(function, stage, runner, step) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end

  def success_transactions_number(number) do
    Gauge.set([name: :success_transactions_number, registry: :public], number)
  end

  def media_processing_time(seconds) do
    Histogram.observe([name: :media_processing_time], seconds)
  end

  def weekly_success_transactions_number(number) do
    Gauge.set([name: :weekly_success_transactions_number, registry: :public], number)
  end

  def deployed_smart_contracts_number(number) do
    Gauge.set([name: :deployed_smart_contracts_number, registry: :public], number)
  end

  def verified_smart_contracts_number(number) do
    Gauge.set([name: :verified_smart_contracts_number, registry: :public], number)
  end

  def new_addresses_number(number) do
    Gauge.set([name: :new_addresses_number, registry: :public], number)
  end

  def new_tokens_number(number) do
    Gauge.set([name: :new_tokens_number, registry: :public], number)
  end

  def new_token_transfers_number(number) do
    Gauge.set([name: :new_token_transfers_number, registry: :public], number)
  end

  def simplified_active_addresses_number(number) do
    Gauge.set([name: :active_addresses_number, registry: :public], number)
  end

  def increment_successfully_uploaded_media_number do
    Counter.inc(name: :successfully_uploaded_media_number, registry: :public)
  end

  def increment_failed_uploading_media_number do
    Counter.inc(name: :failed_uploading_media_number, registry: :public)
  end

  defp batch_average_time(average_time) do
    Gauge.set([name: :batch_average_time], average_time)
  end

  @doc """
  Prepares a batch metric from a list of batch data.

  ## Parameters

    - `batches`: A list of maps, where each map represents a batch with the following keys:
    - `:number` (integer): The batch number.
    - `:timestamp` (DateTime.t): The timestamp of the batch.

  ## Returns

    - `{:ok, %{latest_batch_number: integer, latest_batch_timestamp: DateTime.t(), average_batch_time: integer}}`:
      - `:latest_batch_number`: The number of the latest batch.
      - `:latest_batch_timestamp`: The timestamp of the latest batch.
      - `:average_batch_time`: The average time in seconds between batches, or `0` if there is only one batch.
    - `{:error, :not_found}`: If the input list of batches is empty.

  ## Examples

    - When the list of batches is empty:
      ```elixir
      prepare_batch_metric([])
      # => {:error, :not_found}
      ```

    - When the list contains a single batch:
      ```elixir
      prepare_batch_metric([%{number: 1, timestamp: ~U[2023-01-01T00:00:00Z]}])
      # => {:ok, %{latest_batch_number: 1, latest_batch_timestamp: ~U[2023-01-01T00:00:00Z], average_batch_time: 0}}
      ```

    - When the list contains multiple batches:
      ```elixir
      prepare_batch_metric([
        %{number: 3, timestamp: ~U[2023-01-01T00:02:00Z]},
        %{number: 2, timestamp: ~U[2023-01-01T00:01:00Z]},
        %{number: 1, timestamp: ~U[2023-01-01T00:00:00Z]}
      ])
      # => {:ok, %{latest_batch_number: 3, latest_batch_timestamp: ~U[2023-01-01T00:02:00Z], average_batch_time: 60}}
      ```
  """
  @spec prepare_batch_metric([%{number: integer, timestamp: DateTime.t()}]) ::
          {:ok,
           %{
             latest_batch_number: integer,
             latest_batch_timestamp: DateTime.t(),
             average_batch_time: integer
           }}
          | {:error, :not_found}
  def prepare_batch_metric(batches) do
    case batches do
      [] ->
        {:error, :not_found}

      [batch] ->
        batch_average_time(0)

        {
          :ok,
          %{
            latest_batch_number: batch.number,
            latest_batch_timestamp: batch.timestamp,
            average_batch_time: 0
          }
        }

      batches ->
        latest_batch = List.first(batches)
        older_batch = List.last(batches)
        average_time = div(DateTime.diff(latest_batch.timestamp, older_batch.timestamp, :second), length(batches) - 1)
        batch_average_time(average_time)

        {
          :ok,
          %{
            latest_batch_number: latest_batch.number,
            latest_batch_timestamp: latest_batch.timestamp,
            average_batch_time: average_time
          }
        }
    end
  end
end
