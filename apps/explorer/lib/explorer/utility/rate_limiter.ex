defmodule Explorer.Utility.RateLimiter do
  @moduledoc """
  Rate limit logic with separation by action type and exponential backoff for bans.
  """
  alias Explorer.Utility.Hammer

  use GenServer

  require Logger

  @ets_table_name :rate_limiter
  @redis_conn_name :redix_rate_limiter

  def start_link(_) do
    config = Application.get_env(:explorer, __MODULE__)

    case config[:storage] do
      :redis -> Redix.start_link(config[:redis_url], name: @redis_conn_name)
      :ets -> GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end
  end

  def init(_) do
    table_opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(@ets_table_name, table_opts)

    {:ok, %{}}
  end

  def handle_info({:delete, key}, state) do
    :ets.delete(@ets_table_name, key)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @doc """
    Checks if `identifier` is banned from `action` right now.
    If it's not banned, then checks the current calls rate and decides if it should be banned.
    Returns `:allow` if `identifier` is not banned from `action` and its current calls rate is below the limit.
    Returns `:deny` in other case.
  """
  @spec check_rate(String.t() | nil, atom()) :: :allow | :deny
  def check_rate(nil, _action), do: :allow

  def check_rate(identifier, action) do
    with {:enabled, true} <- {:enabled, Application.get_env(:explorer, __MODULE__)[:enabled]},
         key = key(identifier, action),
         {:ban_data, _key, {:ok, ban_data}} when not is_nil(ban_data) <- {:ban_data, key, get_value(key)},
         [try_after, bans_count] = parse_ban_data(ban_data),
         {:ban_expired, true} <- {:ban_expired, now() > try_after} do
      do_check_rate_limit(key, bans_count, action)
    else
      {:enabled, _false} -> :allow
      {:ban_data, key, _not_found} -> do_check_rate_limit(key, 0, action)
      {:ban_expired, false} -> :deny
    end
  end

  defp do_check_rate_limit(key, bans_count, action) do
    if rate_limit_reached?(key, action) do
      do_ban(key, bans_count, action)
      :deny
    else
      :allow
    end
  end

  defp key(identifier, action), do: "#{Application.get_env(:block_scout_web, :chain_id)}_#{identifier}_#{action}"

  defp parse_ban_data(ban_data) do
    ban_data
    |> String.split(":")
    |> Enum.map(&String.to_integer/1)
  end

  defp now, do: :os.system_time(:second)

  defp rate_limit_reached?(key, action) do
    config = Application.get_env(:explorer, __MODULE__)[action]

    time_interval_limit = config[:time_interval_limit]
    limit_by_ip = config[:limit_by_ip]

    case Hammer.hit(key, time_interval_limit, limit_by_ip) do
      {:allow, _count} ->
        false

      {:deny, _limit} ->
        true

      {:error, error} ->
        Logger.error(fn -> ["Rate limit check error: ", inspect(error)] end)
        false
    end
  end

  defp do_ban(key, bans_count, action) do
    config = Application.get_env(:explorer, __MODULE__)[action]

    coef = config[:exp_timeout_coeff]
    max_ban_interval = config[:max_ban_interval]
    max_bans_count = :math.log(max_ban_interval / 1000 / coef)

    ban_interval = floor(coef * :math.exp(min(bans_count, max_bans_count)))
    expire_after = ban_interval * 1000 + config[:limitation_period]

    set_value(key, "#{now() + ban_interval}:#{bans_count + 1}", expire_after)
  end

  defp get_value(key) do
    case Application.get_env(:explorer, __MODULE__)[:storage] do
      :redis ->
        Redix.command(@redis_conn_name, ["GET", key])

      :ets ->
        case :ets.lookup(@ets_table_name, key) do
          [{_key, value}] -> {:ok, value}
          _ -> :not_found
        end
    end
  end

  defp set_value(key, value, expire_after) do
    case Application.get_env(:explorer, __MODULE__)[:storage] do
      :redis ->
        case Redix.command(@redis_conn_name, ["SET", key, value, "EX", floor(expire_after / 1000)]) do
          {:ok, "OK"} ->
            :ok

          {:error, err} ->
            Logger.error(["Failed to set value for key #{key} in Redis: ", inspect(err)])
            :error
        end

      :ets ->
        :ets.insert(@ets_table_name, {key, value})
        Process.send_after(self(), {:delete, key}, expire_after)
    end
  end
end
