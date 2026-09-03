# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.TokenCountersUpdater do
  @moduledoc """
  Periodically exports the counters of cataloged tokens to the Multichain
  Search service.

  The counter values are read straight from the `tokens.holder_count` and
  `tokens.transfer_count` columns — they are maintained by the incremental
  counters machinery (import-time holder deltas and
  `Explorer.Chain.Cache.Counters.TokenCountersConsolidator`), so no aggregates
  run here. Tokens not yet consolidated are skipped until their first
  consolidation.
  """
  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain.Token
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Indexer.BufferedTask

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

    if !state do
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
    # BufferedTask re-runs init whenever the queue drains; throttle the full
    # export sweep to the configured interval (the legacy implementation was
    # implicitly throttled by the metadata staleness predicate it reused)
    interval = Application.get_env(:indexer, __MODULE__)[:milliseconds_interval]
    last_stream_at = :persistent_term.get({__MODULE__, :last_stream_at}, 0)
    now = System.system_time(:millisecond)

    if now - last_stream_at >= interval do
      :persistent_term.put({__MODULE__, :last_stream_at}, now)

      {:ok, tokens} = Token.stream_cataloged_tokens_for_counters(initial, reducer, true)

      tokens
    else
      initial
    end
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    Logger.debug("exporting token counters")

    entries
    |> Enum.reduce(%{}, fn token, acc ->
      data_for_multichain =
        MultichainSearch.prepare_token_counters_for_queue(token.transfer_count || 0, token.holder_count || 0)

      Map.put(acc, token.contract_address_hash.bytes, data_for_multichain)
    end)
    |> MultichainSearch.send_token_info_to_queue(:counters)

    :ok
  end
end
