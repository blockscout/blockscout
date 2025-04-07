defmodule Explorer.Utility.RateLimiter do
  @moduledoc """
  Rate limit logic with separation by action type and exponential backoff for bans.
  """

  use GenServer

  require Logger

  @ets_table_name :rate_limiter

  def start_link(_) do
    config = Application.get_env(:explorer, __MODULE__)

    case config[:storage] do
      :redis -> Redix.start_link(config[:redis_url], name: :redix_rate_limiter)
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

  @spec check_rate(String.t() | nil, atom()) :: :allow | :deny
  def check_rate(nil, _action), do: :allow

  def check_rate(identifier, action) do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      key = key(identifier, action)

      case get_value(key) do
        {:ok, ban_data} when not is_nil(ban_data) ->
          [try_after, bans_count] = parse_ban_data(ban_data)

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if now() > try_after do
            do_check_rate_limit(key, bans_count, action)
          else
            :deny
          end

        _ ->
          do_check_rate_limit(key, 0, action)
      end
    else
      :allow
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

  defp key(identifier, action), do: "#{identifier}_#{action}"

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

    case Hammer.check_rate(key, time_interval_limit, limit_by_ip) do
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
    expire_after = ban_interval + config[:limitation_period]

    set_value(key, "#{now() + ban_interval}:#{bans_count + 1}", expire_after)
  end

  defp get_value(key) do
    case Application.get_env(:explorer, __MODULE__)[:storage] do
      :redis ->
        Redix.command(:redix, ["GET", key])

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
        Redix.command(:redix, ["SET", key, value, "EX", expire_after])

      :ets ->
        :ets.insert(@ets_table_name, {key, value})
        Process.send_after(self(), {:delete, key}, expire_after)
    end
  end
end
