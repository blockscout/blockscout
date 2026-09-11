# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.OnDemand.TokenTotalSupply do
  @moduledoc """
  Ensures that we have a reasonably up to date token supply.

  The fetch is triggered from API request handlers. To keep the request path
  cheap and the GenServer mailbox bounded:

    * the staleness check runs in the caller, using the already loaded
      `t:Explorer.Chain.Token.t/0`, before anything is enqueued;
    * an ETS table records tokens that are in flight or failed recently, so a
      token is enqueued at most once per attempt and failing tokens back off;
    * the JSON RPC call runs in a task under `__MODULE__.TaskSupervisor`,
      never in the GenServer itself, and at most `max_concurrency` tasks run at
      a time. Requests arriving above the cap are dropped and can be retried
      by a later request.
  """

  use GenServer
  use Indexer.Fetcher, restart: :permanent

  require Logger

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Token
  alias Explorer.Token.MetadataRetriever
  alias Explorer.Utility.RateLimiter

  @table_name :token_total_supply_on_demand
  @ttl_in_blocks 1
  @default_max_concurrency 5
  @default_threshold :timer.minutes(5)
  @sweep_interval :timer.minutes(1)

  # Non-token entries kept in the same ETS table.
  @slots_key :slots
  @max_concurrency_key :max_concurrency

  @typep key :: binary()

  ## Interface

  @doc """
  Schedules a total supply refresh for `token` when it is stale.

  Returns `:ok` in all cases. Does nothing when the fetcher is disabled or not
  running, when the token is fresh, when the caller is rate limited, or when
  the token is already in flight or failed recently.
  """
  @spec trigger_fetch(String.t() | nil, Token.t()) :: :ok
  def trigger_fetch(caller \\ nil, %Token{} = token) do
    with false <- __MODULE__.Supervisor.disabled?(),
         true <- table_exists?(),
         true <- stale?(token, BlockNumber.get_max()),
         :allow <- RateLimiter.check_rate(caller, :on_demand),
         key = key(token),
         true <- claim(key),
         true <- reserve_slot(key) do
      GenServer.cast(__MODULE__, {:fetch, token})
    else
      _ -> :ok
    end
  end

  ## Callbacks

  def start_link([init_opts, server_opts]) do
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(init_opts) do
    ensure_table()
    schedule_sweep()

    max_concurrency =
      Keyword.get(init_opts, :max_concurrency) ||
        Application.get_env(:indexer, __MODULE__, [])[:max_concurrency] ||
        @default_max_concurrency

    :ets.insert(@table_name, [{@slots_key, 0}, {@max_concurrency_key, max_concurrency}])

    {:ok, %{running: %{}}}
  end

  @impl true
  def handle_cast({:fetch, %Token{} = token}, %{running: running} = state) do
    key = key(token)

    if key in Map.values(running) do
      release_slot()
      {:noreply, state}
    else
      %Task{ref: ref} = Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fn -> do_fetch(token) end)
      {:noreply, %{state | running: Map.put(running, ref, key)}}
    end
  end

  @impl true
  def handle_info({ref, result}, %{running: running} = state) when is_map_key(running, ref) do
    Process.demonitor(ref, [:flush])
    {key, running} = Map.pop(running, ref)
    finish(key, result)
    release_slot()

    {:noreply, %{state | running: running}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{running: running} = state) when is_map_key(running, ref) do
    {key, running} = Map.pop(running, ref)
    Logger.error("On-demand token total supply fetch crashed: #{inspect(reason)}")
    mark_failed(key)
    release_slot()

    {:noreply, %{state | running: running}}
  end

  def handle_info(:sweep, %{running: running} = state) do
    sweep(Map.values(running))
    schedule_sweep()

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  ## Implementation

  @spec do_fetch(Token.t()) :: :ok | :error | {:error, Ecto.Changeset.t()}
  defp do_fetch(%Token{contract_address_hash: contract_address_hash} = token) do
    case MetadataRetriever.get_total_supply_of(to_string(contract_address_hash)) do
      %{total_supply: _} = token_params ->
        case Token.update(token, token_params) do
          {:ok, updated_token} ->
            Publisher.broadcast(%{token_total_supply: [updated_token]}, :on_demand)
            :ok

          {:error, _changeset} = error ->
            error
        end

      _ ->
        :error
    end
  end

  defp finish(key, :ok), do: :ets.delete(@table_name, key)

  defp finish(key, error) do
    Logger.debug(fn -> "On-demand token total supply fetch failed: #{inspect(error)}" end)
    mark_failed(key)
  end

  defp mark_failed(key), do: :ets.insert(@table_name, {key, :failed, now_ms()})

  @spec stale?(Token.t(), non_neg_integer()) :: boolean()
  defp stale?(%Token{skip_metadata: true, total_supply_updated_at_block: nil}, _max_block_number), do: false
  defp stale?(%Token{total_supply_updated_at_block: nil}, _max_block_number), do: true

  defp stale?(%Token{total_supply_updated_at_block: updated_at_block}, max_block_number),
    do: max_block_number - updated_at_block > @ttl_in_blocks

  # Marks the token as in flight. Returns `false` when it is already in flight
  # or failed less than `threshold` ago.
  @spec claim(key()) :: boolean()
  defp claim(key) do
    now = now_ms()

    case :ets.lookup(@table_name, key) do
      [] ->
        :ets.insert_new(@table_name, {key, :in_flight, now})

      [{_key, :in_flight, _at}] ->
        false

      [{_key, :failed, _failed_at}] ->
        # Atomically replace the failure record only if it is old enough, so
        # concurrent callers cannot both claim the same expired token.
        expired_before = now - threshold_ms()

        match_spec = [
          {{key, :failed, :"$1"}, [{:"=<", :"$1", expired_before}], [{{{:const, key}, :in_flight, {:const, now}}}]}
        ]

        :ets.select_replace(@table_name, match_spec) == 1
    end
  end

  # Reserves one of `max_concurrency` fetch slots. On failure, releases the
  # token claim so a later request can retry.
  @spec reserve_slot(key()) :: boolean()
  defp reserve_slot(key) do
    if :ets.update_counter(@table_name, @slots_key, {2, 1}) > max_concurrency() do
      release_slot()
      :ets.delete(@table_name, key)
      false
    else
      true
    end
  end

  defp release_slot, do: :ets.update_counter(@table_name, @slots_key, {2, -1})

  defp max_concurrency do
    case :ets.lookup(@table_name, @max_concurrency_key) do
      [{_key, max_concurrency}] -> max_concurrency
      [] -> @default_max_concurrency
    end
  end

  # Removes expired failure records and in-flight markers that are not backed
  # by a running task (for example, casts lost while the server restarted).
  @spec sweep([key()]) :: :ok
  defp sweep(running_keys) do
    now = now_ms()
    threshold = threshold_ms()

    :ets.foldl(
      fn
        {key, :failed, failed_at}, acc when now - failed_at >= threshold ->
          [key | acc]

        {key, :in_flight, started_at}, acc when now - started_at >= 2 * threshold ->
          if key in running_keys, do: acc, else: [key | acc]

        _entry, acc ->
          acc
      end,
      [],
      @table_name
    )
    |> Enum.each(&:ets.delete(@table_name, &1))
  end

  defp ensure_table do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true, write_concurrency: true])
    end
  end

  defp table_exists?, do: :ets.whereis(@table_name) != :undefined

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)

  defp key(%Token{contract_address_hash: %{bytes: bytes}}), do: bytes

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp threshold_ms do
    Application.get_env(:indexer, __MODULE__, [])[:threshold] || @default_threshold
  end
end
