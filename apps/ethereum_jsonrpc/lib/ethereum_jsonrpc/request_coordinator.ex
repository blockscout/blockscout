defmodule EthereumJSONRPC.RequestCoordinator do
  @moduledoc """
  Coordinates requests with a backoff strategy.

  This module leverages `EthereumJSONRPC.RollingWindow` to track request timeout
  that have occurred recently. Options for this functionality can be changed at
  the application configuration level.

  ## Configuration

  The following are the expected and supported options for this module:

  * `:rolling_window_opts` - Options for the process tracking timeouts
    * `:window_count` - Number of windows
    * `:duration` - Total amount of time to count timeout events in milliseconds
    * `:table` - name of the ets table to store the data in
  * `:wait_per_timeout` - Milliseconds to wait for each recent timeout within
    the tracked window
  * `:max_jitter` - Maximum amount of time in milliseconds to be added to each
    wait before multiplied by timeout count
  * `:throttle_rolling_window_opts` - Options for the process tracking all requests
    * `:window_count` - Number of windows
    * `:duration` - Total amount of time to count events in milliseconds
    * `:table` - name of the ets table to store the data in
  * `:throttle_rate_limit` - The total number of requests allowed in the all windows.

  See the docs for `EthereumJSONRPC.RollingWindow` for more documentation for
  `:rolling_window_opts` and `:throttle_rolling_window_opts`.

  This is how the wait time for each request is calculated:

      (wait_per_timeout + jitter) * recent_timeouts

  where jitter is some random number between 0 and max_jitter.

  ### Example Configuration

      config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
        rolling_window_opts: [
          window_count: 6,
          duration: :timer.minutes(1),
          table: EthereumJSONRPC.RequestCoordinator.TimeoutCounter
        ],
        wait_per_timeout: :timer.seconds(10),
        max_jitter: :timer.seconds(1)
        throttle_rate_limit: 60,
        throttle_rolling_window_opts: [
          window_count: 3,
          duration: :timer.seconds(10),
          table: EthereumJSONRPC.RequestCoordinator.RequestCounter
        ]

  With this configuration, timeouts are tracked for 6 windows of 10 seconds for a total of 1 minute.
  Requests are tracked for 3 windows of 10 seconds, for a total of 30 seconds, and
  """

  require EthereumJSONRPC.Tracer

  alias EthereumJSONRPC.{RollingWindow, Tracer, Transport}

  @error_key :throttleable_error_count
  @throttle_key :throttle_requests_count

  @doc """
  Performs a JSON RPC request and adds necessary backoff.

  In the event that too many requests have timed out recently and the current
  request were to exceed someout threshold, the request isn't performed and
  `{:error, :timeout}` is returned.
  """
  @spec perform(Transport.request(), Transport.t(), Transport.options(), non_neg_integer()) ::
          {:ok, Transport.result()} | {:error, term()}
  @spec perform(Transport.batch_request(), Transport.t(), Transport.options(), non_neg_integer()) ::
          {:ok, Transport.batch_response()} | {:error, term()}
  def perform(request, transport, transport_options, throttle_timeout) do
    sleep_time = sleep_time()

    if sleep_time <= throttle_timeout do
      :timer.sleep(sleep_time)
      remaining_wait_time = throttle_timeout - sleep_time

      case throttle_request(remaining_wait_time) do
        :ok ->
          trace_request(request, fn ->
            request
            |> transport.json_rpc(transport_options)
            |> handle_transport_response()
          end)

        :error ->
          {:error, :timeout}
      end
    else
      :timer.sleep(throttle_timeout)

      {:error, :timeout}
    end
  end

  defp trace_request([request | _], fun) do
    trace_request(request, fun)
  end

  defp trace_request(%{method: method}, fun) do
    Tracer.span "RequestCoordinator.perform/4", resource: method, service: :ethereum_jsonrpc do
      fun.()
    end
  end

  defp trace_request(_, fun), do: fun.()

  defp handle_transport_response({:error, {error_type, _}} = error) when error_type in [:bad_gateway, :bad_response] do
    RollingWindow.inc(table(), @error_key)
    inc_throttle_table()
    error
  end

  defp handle_transport_response({:error, :timeout} = error) do
    RollingWindow.inc(table(), @error_key)
    inc_throttle_table()
    error
  end

  defp handle_transport_response(response) do
    inc_throttle_table()
    response
  end

  defp inc_throttle_table do
    if config(:throttle_rolling_window_opts) do
      RollingWindow.inc(throttle_table(), @throttle_key)
    end
  end

  defp throttle_request(
         remaining_time,
         rate_limit \\ config(:throttle_rate_limit),
         opts \\ config(:throttle_rolling_window_opts)
       ) do
    if opts[:throttle_rate_limit] && RollingWindow.count(throttle_table(), @throttle_key) >= rate_limit do
      if opts[:duration] >= remaining_time do
        :timer.sleep(remaining_time)

        :error
      else
        new_remaining_time = remaining_time - opts[:duration]
        :timer.sleep(opts[:duration])

        throttle_request(new_remaining_time, rate_limit, opts)
      end
    else
      :ok
    end
  end

  defp sleep_time do
    wait_coefficient = RollingWindow.count(table(), @error_key)
    jitter = :rand.uniform(config!(:max_jitter))
    wait_per_timeout = config!(:wait_per_timeout)

    wait_coefficient * (wait_per_timeout + jitter)
  end

  defp table do
    :rolling_window_opts
    |> config!()
    |> Keyword.fetch!(:table)
  end

  defp throttle_table do
    case config(:throttle_rolling_window_opts) do
      nil -> :ignore
      keyword -> Keyword.fetch!(keyword, :table)
    end
  end

  defp config!(key) do
    :ethereum_jsonrpc
    |> Application.get_env(__MODULE__)
    |> Keyword.fetch!(key)
  end

  defp config(key) do
    :ethereum_jsonrpc
    |> Application.get_env(__MODULE__)
    |> Keyword.get(key)
  end
end
