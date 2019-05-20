defmodule Explorer.Chain.BlockCountCache do
  @moduledoc """
  Cache for block count.
  """

  require Logger

  use GenServer

  alias Explorer.Chain

  # 10 minutes
  @cache_period 1_000 * 60 * 10
  @key "count"
  @default_value nil
  @name __MODULE__

  def start_link(params) do
    name = params[:name] || @name
    params_with_name = Keyword.put(params, :name, name)

    GenServer.start_link(__MODULE__, params_with_name, name: name)
  end

  def init(params) do
    cache_period = period_from_env_var() || params[:cache_period] || @cache_period
    current_value = params[:default_value] || @default_value
    name = params[:name]

    init_ets_table(name)

    {:ok, {{cache_period, current_value, name}, nil}}
  end

  def count(process_name \\ __MODULE__) do
    GenServer.call(process_name, :count)
  end

  def handle_call(:count, _, {{cache_period, default_value, name}, task}) do
    {count, task} =
      case cached_values(name) do
        nil ->
          {default_value, update_cache(task, name)}

        {cached_value, timestamp} ->
          task =
            if current_time() - timestamp > cache_period do
              update_cache(task, name)
            end

          {cached_value, task}
      end

    {:reply, count, {{cache_period, default_value, name}, task}}
  end

  def update_cache(nil, name) do
    async_update_cache(name)
  end

  def update_cache(task, _) do
    task
  end

  def handle_cast({:update_cache, value}, {{cache_period, default_value, name}, _}) do
    current_time = current_time()
    tuple = {value, current_time}

    table_name = table_name(name)

    :ets.insert(table_name, {@key, tuple})

    {:noreply, {{cache_period, default_value, name}, nil}}
  end

  def handle_info({:DOWN, _, _, _, _}, {{cache_period, default_value, name}, _}) do
    {:noreply, {{cache_period, default_value, name}, nil}}
  end

  def handle_info(_, {{cache_period, default_value, name}, _}) do
    {:noreply, {{cache_period, default_value, name}, nil}}
  end

  # sobelow_skip ["DOS"]
  defp table_name(name) do
    name
    |> Atom.to_string()
    |> Macro.underscore()
    |> String.to_atom()
  end

  def async_update_cache(name) do
    Task.async(fn ->
      try do
        result = Chain.fetch_count_consensus_block()

        GenServer.cast(name, {:update_cache, result})
      rescue
        e ->
          Logger.debug([
            "Coudn't update block count test #{inspect(e)}"
          ])
      end
    end)
  end

  defp init_ets_table(name) do
    table_name = table_name(name)

    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end
  end

  defp cached_values(name) do
    table_name = table_name(name)

    case :ets.lookup(table_name, @key) do
      [{_, cached_values}] -> cached_values
      _ -> nil
    end
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  defp period_from_env_var do
    case System.get_env("BLOCK_COUNT_CACHE_PERIOD") do
      value when is_binary(value) ->
        case Integer.parse(value) do
          {integer, ""} -> integer * 1_000
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
