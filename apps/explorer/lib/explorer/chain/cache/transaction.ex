defmodule Explorer.Chain.Cache.Transaction do
  @moduledoc """
  Cache for estimated transaction count.
  """

  use Explorer.Chain.MapCache,
    name: :transaction_count,
    key: :count,
    key: :async_task,
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl],
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

      max(rows, 0)
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
              "Coudn't update transaction count: ",
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
end
