defmodule Explorer.Chain.Cache.Block do
  @moduledoc """
  Cache for block count.
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  use Explorer.Chain.MapCache,
    name: :block_count,
    key: :count,
    key: :async_task,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
    ttl_check_interval: :timer.seconds(1),
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
              "Coudn't update block count: ",
              Exception.format(:error, e, __STACKTRACE__)
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
