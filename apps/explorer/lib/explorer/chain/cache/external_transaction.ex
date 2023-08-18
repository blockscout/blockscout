defmodule Explorer.Chain.Cache.ExternalTransaction do
  @moduledoc """
  Cache for estimated external transaction count.
  """

  @default_cache_period :timer.hours(2)

  use Explorer.Chain.MapCache,
    name: :external_transaction_count,
    key: :count,
    key: :async_task,
    global_ttl: cache_period(),
    ttl_check_interval: :timer.minutes(15),
    callback: &async_task_on_deletion(&1)

  require Logger

  alias Ecto.Adapters.SQL
  alias Explorer.Chain.ExternalTransaction
  alias Explorer.Repo

  @doc """
  Estimated count of `t:Explorer.Chain.ExternalTransaction.t/0`.

  Estimated count of both collated and pending external transactions using the ext_transactions table statistics.
  """
  @spec estimated_count() :: non_neg_integer()
  def estimated_count do
    IO.puts("ExternalTransaction estimated_count")
    IO.inspect(__MODULE__)
    cached_value = __MODULE__.get_count()
    IO.puts("cached_value #{inspect(cached_value)}")
    IO.inspect(cached_value)

    if is_nil(cached_value) do
      %Postgrex.Result{rows: [[rows]]} =
        SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='external_transactions'")

      IO.puts("rows #{inspect(rows)}")

      rows
    else
      IO.puts("rows #{inspect(cached_value)}")
      cached_value
    end
  end

  defp handle_fallback(:count) do
    IO.puts("ExternalTransaction handle_fallback count")
    # This will get the task PID if one exists and launch a new task if not
    # See next `handle_fallback` definition
    get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:async_task) do
    IO.puts("ExternalTransaction handle_fallback async_task")
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start(fn ->
        try do
          result = Repo.aggregate(ExternalTransaction, :count, :hash, timeout: :infinity)

          set_count(result)
        rescue
          e ->
            Logger.debug([
              "Coudn't update external transaction count test #{inspect(e)}"
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
    IO.puts("ExternalTransaction cache_period")
    "CACHE_ETXS_COUNT_PERIOD"
    |> System.get_env("")
    |> Integer.parse()
    |> case do
      {integer, ""} -> :timer.seconds(integer)
      _ -> @default_cache_period
    end
  end
end
