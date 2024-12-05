defmodule Explorer.Prometheus.Instrumenter do
  @moduledoc """
  Blocks fetch and import metrics for `Prometheus`.
  """

  use Prometheus.Metric
  require Logger

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
    help: "Number of failed uploading to CDN media",
    registry: :public
  ]

  def block_import_stage_runner(function, stage, runner, step) do
    {time, result} = :timer.tc(function)

    Histogram.observe([name: :block_import_stage_runner_duration_microseconds, labels: [stage, runner, step]], time)

    result
  end

  def success_transactions_number(number) do
    Gauge.set([name: :success_transactions_number, registry: :public], number)
  end

  def media_processing_time(seconds) do
    Logger.info(to_string(seconds))
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
end
