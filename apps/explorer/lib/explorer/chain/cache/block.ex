defmodule Explorer.Chain.Cache.Block do
  @moduledoc """
  Cache for block count.
  """

  @default_cache_period :timer.hours(2)

  import Ecto.Query,
    only: [
      from: 2
    ]

  use Explorer.Chain.MapCache,
    name: :block_count,
    key: :count,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(15),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias Explorer.Chain.Block
  alias Explorer.Repo

  @doc """
  Estimated count of `t:Explorer.Chain.Block.t/0`.

  Estimated count of consensus blocks.
  """
  @spec estimated_count() :: non_neg_integer()
  def estimated_count do
    cached_value = __MODULE__.get_count()

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[count]]} = Repo.query!("SELECT reltuples FROM pg_class WHERE relname = 'blocks';")

      trunc(count * 0.90)
    else
      cached_value
    end
  end

  @spec last_coincident(String) :: non_neg_integer()
  def last_coincident(context) do
    result = %Postgrex.Result{} = Repo.query!("SELECT *
FROM blocks
WHERE (is_" <> context <> "_coincident = true)
ORDER BY number DESC
LIMIT 1;
")
    result = result |> Map.get(:rows)
    if result |> Kernel.length() == 0 do
      nil
    else
      result |> List.first() |> Enum.at(7)
    end
  end

  defp handle_fallback(:count) do
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition
    get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          result = fetch_count_consensus_block()

          set_count(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update block count test #{inspect(e)}"
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time the
  # `count` expires (unless there is one already running)
  defp async_task_on_deletion({:delete, _, :count}), do: get_async_task()

  defp async_task_on_deletion(_data), do: nil

  defp cache_period do
    "CACHE_BLOCK_COUNT_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end

  @spec fetch_count_consensus_block() :: non_neg_integer
  defp fetch_count_consensus_block do
    query =
      from(block in Block,
        select: count(block.hash),
        where: block.consensus == true
      )

    Repo.one!(query, timeout: :infinity) || 0
  end
end
