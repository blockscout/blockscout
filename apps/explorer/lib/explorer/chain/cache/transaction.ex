defmodule Explorer.Chain.Cache.Transaction do
  @moduledoc """
  Cache for estimated transaction count.
  """

  @default_cache_period :timer.hours(2)

  use Explorer.Chain.MapCache,
    name: :transaction_count,
    key: :count,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(15),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @doc """
  Estimated count of `t:Explorer.Chain.Transaction.t/0`.

  Estimated count of both collated and pending transactions using the transactions table statistics.
  """
  @spec estimated_count() :: non_neg_integer()
  def estimated_count do
    cached_value = __MODULE__.get_count()

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[rows]]} =
        SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='transactions'")

      rows
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
          result = Repo.aggregate(Transaction, :count, :hash, timeout: :infinity)

          set_count(result)
        rescue
          e ->
            Logger.debug([
              "Couldn't update transaction count test #{inspect(e)}"
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
    "CACHE_TXS_COUNT_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end
end
