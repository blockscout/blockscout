# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Explorer metrics for `Prometheus`.
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
    name: :stats_import_stage_runner_duration_microseconds,
    labels: [:stats_type],
    buckets: [1000, 5000, 10000, 100_000],
    duration_unit: :microseconds,
    help: "Stats import stage runner duration microseconds"
  ]

  # Public chain metrics exposed at /public_metrics endpoint

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

  # metrics of NFT media handler

  @histogram [
    name: :media_processing_time,
    buckets: :default,
    duration_unit: :seconds,
    help: "Time in seconds taken for media resizing and uploading"
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

  # metrics of market data sources

  @counter [
    name: :market_source_requests_count,
    labels: [:source, :endpoint, :status],
    help: "Number of HTTP requests sent to market data sources by source, endpoint type and outcome"
  ]

  @gauge [name: :average_block_time, help: "Average block time in milliseconds"]

  @gauge [name: :batch_average_time, help: "L2 average batch time"]

  @gauge [name: :latest_deposit_l1_number, help: "L2 latest deposit L1 block number"]
  @gauge [name: :latest_deposit_timestamp, help: "L2 latest deposit timestamp"]
  @gauge [name: :average_deposit_time, help: "L2 average deposit time"]

  @gauge [name: :latest_withdrawal_l2_number, help: "L2 latest withdrawal L2 block number"]
  @gauge [name: :latest_withdrawal_timestamp, help: "L2 latest withdrawal timestamp"]
  @gauge [name: :average_withdrawal_time, help: "L2 average withdrawal time"]

  def setup do
    prepare_batch_metric([])
    prepare_deposit_metric([])
    prepare_withdrawal_metric([])
  end

  @doc """
  Defines the metric for the full processing time of a block (in microseconds).
  """
  @spec block_import_stage_runner(function :: (-> any()), stage :: atom(), runner :: atom(), step :: atom()) ::
          any()
  def block_import_stage_runner(function, stage, runner, step) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end

  @doc """
  Defines the metric for the full processing time of a stats import stage runner
  (in microseconds).
  """
  @spec stats_import_stage_runner(function :: (-> any()), stats_type :: atom()) :: any()
  def stats_import_stage_runner(function, stats_type) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :stats_import_stage_runner_duration_microseconds, labels: [stats_type]], time)

    result
  end

  @doc """
  Defines the metric for the number of successful transactions in the period (default is 1 day).
  """
  @spec success_transactions_number(number :: integer()) :: :ok
  def success_transactions_number(number) do
    Gauge.set([name: :success_transactions_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of weekly successful transactions.
  """
  @spec weekly_success_transactions_number(number :: integer()) :: :ok
  def weekly_success_transactions_number(number) do
    Gauge.set([name: :weekly_success_transactions_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of deployed smart-contracts in the period (default is 1 day).
  """
  @spec deployed_smart_contracts_number(number :: integer()) :: :ok
  def deployed_smart_contracts_number(number) do
    Gauge.set([name: :deployed_smart_contracts_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of verified smart-contracts in the period (default is 1 day).
  """
  @spec verified_smart_contracts_number(number :: integer()) :: :ok
  def verified_smart_contracts_number(number) do
    Gauge.set([name: :verified_smart_contracts_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of new addresses in the period (default is 1 day).
  """
  @spec new_addresses_number(number :: integer()) :: :ok
  def new_addresses_number(number) do
    Gauge.set([name: :new_addresses_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of new tokens in the period (default is 1 day).
  """
  @spec new_tokens_number(number :: integer()) :: :ok
  def new_tokens_number(number) do
    Gauge.set([name: :new_tokens_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of new token transfers in the period (default is 1 day).
  """
  @spec new_token_transfers_number(number :: integer()) :: :ok
  def new_token_transfers_number(number) do
    Gauge.set([name: :new_token_transfers_number, registry: :public], number)
  end

  @doc """
  Defines the metric for the number of active EOA addresses in the period (default is 1 day).
  """
  @spec simplified_active_addresses_number(number :: integer()) :: :ok
  def simplified_active_addresses_number(number) do
    Gauge.set([name: :active_addresses_number, registry: :public], number)
  end

  @doc """
  Defines the metric for time taken for media resizing and uploading (in seconds).
  """
  @spec media_processing_time(number()) :: :ok
  def media_processing_time(seconds) do
    Histogram.observe([name: :media_processing_time], seconds)
  end

  @doc """
  Increments the counter for successfully uploaded media to the CDN.
  """
  @spec increment_successfully_uploaded_media_number() :: :ok
  def increment_successfully_uploaded_media_number do
    Counter.inc(name: :successfully_uploaded_media_number, registry: :public)
  end

  @doc """
  Increments the counter for failed media uploads to the CDN.
  """
  @spec increment_failed_uploading_media_number() :: :ok
  def increment_failed_uploading_media_number do
    Counter.inc(name: :failed_uploading_media_number, registry: :public)
  end

  @doc """
  Increments the counter of HTTP requests sent to a market data source.

  ## Parameters
  - `source`: The market data source name, e.g. `"coin_gecko"`
  - `endpoint`: The endpoint type of the request. Requests to the same endpoint with
    different variable parts (token address hash, coin id, pagination offset, etc.)
    share the same endpoint type
  - `status`: The outcome of the request, e.g. `"ok"` or `"429"`
  """
  @spec market_source_request(String.t(), atom(), String.t()) :: :ok
  def market_source_request(source, endpoint, status) do
    Counter.inc(name: :market_source_requests_count, labels: [source, endpoint, status])
  end

  @doc """
  Defines the metric for the average block time in milliseconds.
  """
  @spec average_block_time(number()) :: :ok
  def average_block_time(milliseconds) do
    Gauge.set([name: :average_block_time], milliseconds)
  end

  @spec batch_average_time(integer()) :: :ok
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
        batch_average_time(0)

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

  @spec set_latest_deposit_l1_number(integer()) :: :ok
  defp set_latest_deposit_l1_number(number) do
    Gauge.set([name: :latest_deposit_l1_number], number)
  end

  @spec set_latest_deposit_timestamp(integer()) :: :ok
  defp set_latest_deposit_timestamp(timestamp) do
    Gauge.set([name: :latest_deposit_timestamp], timestamp)
  end

  @spec average_deposit_time(integer()) :: :ok
  defp average_deposit_time(average_time) do
    Gauge.set([name: :average_deposit_time], average_time)
  end

  @doc """
  Prepares deposit Prometheus metrics from a list of deposit data and calculates
  the average time between deposits, in seconds.

  ## Parameters

    - `deposits`: A list of maps sorted in descending order by the deposit L1 block number,
      where each map represents a deposit with the following keys:
      - `:number` (integer): The deposit L1 block number.
      - `:timestamp` (DateTime.t): The timestamp of the deposit.

  ## Returns

    - `{:ok, %{latest_deposit_l1_number: integer, latest_deposit_timestamp: DateTime.t(), average_deposit_time: integer}}`:
      - `:latest_deposit_l1_number`: The L1 block number of the latest deposit.
      - `:latest_deposit_timestamp`: The timestamp of the latest deposit.
      - `:average_deposit_time`: The average time in seconds between deposits, or `0` if there is only one deposit.
    - `{:error, :not_found}`: If the input list of deposits is empty.
  """
  @spec prepare_deposit_metric([%{number: integer, timestamp: DateTime.t()}]) ::
          {:ok,
           %{
             latest_deposit_l1_number: integer,
             latest_deposit_timestamp: DateTime.t(),
             average_deposit_time: integer
           }}
          | {:error, :not_found}
  def prepare_deposit_metric(deposits) do
    case deposits do
      [] ->
        set_latest_deposit_l1_number(0)
        set_latest_deposit_timestamp(0)
        average_deposit_time(0)

        {:error, :not_found}

      [deposit] ->
        set_latest_deposit_l1_number(deposit.number)
        set_latest_deposit_timestamp(DateTime.to_unix(deposit.timestamp))
        average_deposit_time(0)

        {
          :ok,
          %{
            latest_deposit_l1_number: deposit.number,
            latest_deposit_timestamp: deposit.timestamp,
            average_deposit_time: 0
          }
        }

      deposits ->
        latest_deposit = List.first(deposits)
        older_deposit = List.last(deposits)

        average_time =
          div(DateTime.diff(latest_deposit.timestamp, older_deposit.timestamp, :second), length(deposits) - 1)

        set_latest_deposit_l1_number(latest_deposit.number)
        set_latest_deposit_timestamp(DateTime.to_unix(latest_deposit.timestamp))
        average_deposit_time(average_time)

        {
          :ok,
          %{
            latest_deposit_l1_number: latest_deposit.number,
            latest_deposit_timestamp: latest_deposit.timestamp,
            average_deposit_time: average_time
          }
        }
    end
  end

  @spec set_latest_withdrawal_l2_number(integer()) :: :ok
  defp set_latest_withdrawal_l2_number(number) do
    Gauge.set([name: :latest_withdrawal_l2_number], number)
  end

  @spec set_latest_withdrawal_timestamp(integer()) :: :ok
  defp set_latest_withdrawal_timestamp(timestamp) do
    Gauge.set([name: :latest_withdrawal_timestamp], timestamp)
  end

  @spec average_withdrawal_time(integer()) :: :ok
  defp average_withdrawal_time(average_time) do
    Gauge.set([name: :average_withdrawal_time], average_time)
  end

  @doc """
  Prepares withdrawal Prometheus metrics from a list of withdrawal data and calculates
  the average time between withdrawals, in seconds.

  ## Parameters

    - `withdrawals`: A list of maps sorted in descending order by the withdrawal L2 block number,
      where each map represents a withdrawal with the following keys:
      - `:number` (integer): The withdrawal L2 block number.
      - `:timestamp` (DateTime.t): The timestamp of the withdrawal.

  ## Returns

    - `{:ok, %{latest_withdrawal_l2_number: integer, latest_withdrawal_timestamp: DateTime.t(), average_withdrawal_time: integer}}`:
      - `:latest_withdrawal_l2_number`: The L2 block number of the latest withdrawal.
      - `:latest_withdrawal_timestamp`: The timestamp of the latest withdrawal.
      - `:average_withdrawal_time`: The average time in seconds between withdrawals, or `0` if there is only one withdrawal.
    - `{:error, :not_found}`: If the input list of withdrawals is empty.
  """
  @spec prepare_withdrawal_metric([%{number: integer, timestamp: DateTime.t()}]) ::
          {:ok,
           %{
             latest_withdrawal_l2_number: integer,
             latest_withdrawal_timestamp: DateTime.t(),
             average_withdrawal_time: integer
           }}
          | {:error, :not_found}
  def prepare_withdrawal_metric(withdrawals) do
    case withdrawals do
      [] ->
        set_latest_withdrawal_l2_number(0)
        set_latest_withdrawal_timestamp(0)
        average_withdrawal_time(0)

        {:error, :not_found}

      [withdrawal] ->
        set_latest_withdrawal_l2_number(withdrawal.number)
        set_latest_withdrawal_timestamp(DateTime.to_unix(withdrawal.timestamp))
        average_withdrawal_time(0)

        {
          :ok,
          %{
            latest_withdrawal_l2_number: withdrawal.number,
            latest_withdrawal_timestamp: withdrawal.timestamp,
            average_withdrawal_time: 0
          }
        }

      withdrawals ->
        latest_withdrawal = List.first(withdrawals)
        older_withdrawal = List.last(withdrawals)

        average_time =
          div(DateTime.diff(latest_withdrawal.timestamp, older_withdrawal.timestamp, :second), length(withdrawals) - 1)

        set_latest_withdrawal_l2_number(latest_withdrawal.number)
        set_latest_withdrawal_timestamp(DateTime.to_unix(latest_withdrawal.timestamp))
        average_withdrawal_time(average_time)

        {
          :ok,
          %{
            latest_withdrawal_l2_number: latest_withdrawal.number,
            latest_withdrawal_timestamp: latest_withdrawal.timestamp,
            average_withdrawal_time: average_time
          }
        }
    end
  end
end
