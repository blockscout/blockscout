defmodule Indexer.Fetcher.TokenCountersUpdater do
  @moduledoc """
  Updates counters for cataloged tokens.
  """
  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Indexer.BufferedTask
  alias Timex.Duration

  @behaviour BufferedTask

  @max_batch_size 10
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.TokenCountersUpdater.TaskSupervisor,
    metadata: [fetcher: :token_counters_updater]
  ]

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _) do
    counters_updater_milliseconds_interval = Application.get_env(:indexer, __MODULE__)[:milliseconds_interval]

    interval_in_minutes =
      counters_updater_milliseconds_interval
      |> Duration.from_milliseconds()
      |> Duration.to_minutes()
      |> trunc()

    {:ok, tokens} = Token.stream_cataloged_tokens(initial, reducer, interval_in_minutes, true)

    tokens
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    Logger.debug("updating token counters")

    entries
    |> Enum.reduce(%{}, fn token, acc ->
      {transfers_count, holders_count} = Chain.fetch_token_counters(token.contract_address_hash, :infinity)

      data_for_multichain = MultichainSearch.prepare_token_counters_for_queue(transfers_count, holders_count)
      Map.put(acc, token.contract_address_hash.bytes, data_for_multichain)
    end)
    |> MultichainSearch.send_token_info_to_queue(:counters)

    :ok
  end
end
