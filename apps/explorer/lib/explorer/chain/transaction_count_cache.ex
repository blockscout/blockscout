defmodule Explorer.Chain.TransactionCountCache do
  @moduledoc """
  Cache for estimated transaction count.
  """

  use GenServer

  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @tab :transaction_count_cache
  # 2 hours
  @cache_period 1_000 * 60 * 60 * 2
  @default_value 0
  @key "count"
  @name __MODULE__

  def start_link([params, gen_server_options]) do
    GenServer.start_link(__MODULE__, params, name: gen_server_options[:name] || @name)
  end

  def init(params) do
    cache_period = params[:cache_period] || @cache_period
    current_value = params[:default_value] || @default_value

    init_ets_table()

    schedule_cache_update()

    {:ok, {{cache_period, current_value}, nil}}
  end

  def value(process_name \\ __MODULE__) do
    GenServer.call(process_name, :value)
  end

  def handle_call(:value, _, {{cache_period, default_value}, task}) do
    {value, task} =
      case cached_values() do
        nil ->
          {default_value, update_cache(task)}

        {cached_value, timestamp} ->
          task =
            if current_time() - timestamp > cache_period do
              update_cache(task)
            end

          {cached_value, task}
      end

    {:reply, value, {{cache_period, default_value}, task}}
  end

  def update_cache(nil) do
    async_update_cache()
  end

  def update_cache(task) do
    task
  end

  def handle_cast({:update_cache, value}, {{cache_period, default_value}, _}) do
    current_time = current_time()
    tuple = {value, current_time}

    :ets.insert(@tab, {@key, tuple})

    {:noreply, {{cache_period, default_value}, nil}}
  end

  def handle_info({:DOWN, _, _, _, _}, {{cache_period, default_value}, _}) do
    {:noreply, {{cache_period, default_value}, nil}}
  end

  def handle_info(_, {{cache_period, default_value}, _}) do
    {:noreply, {{cache_period, default_value}, nil}}
  end

  def async_update_cache do
    Task.async(fn ->
      result = Repo.aggregate(Transaction, :count, :hash, timeout: :infinity)

      GenServer.cast(__MODULE__, {:update_cache, result})
    end)
  end

  defp init_ets_table do
    if :ets.whereis(@tab) == :undefined do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end
  end

  defp cached_values do
    case :ets.lookup(@tab, @key) do
      [{_, cached_values}] -> cached_values
      _ -> nil
    end
  end

  defp schedule_cache_update do
    Process.send_after(self(), :update_cache, 2_000)
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end
end
