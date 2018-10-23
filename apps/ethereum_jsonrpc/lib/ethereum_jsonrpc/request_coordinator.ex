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
  * `:max_jitter` - Maximimum amount of time in milliseconds to be added to each
    wait before multiplied by timeout count

  See the docs for `EthereumJSONRPC.RollingWindow` for more documentation for
  `:rolling_window_opts`.

  This is how the wait time for each request is calculated:

      (wait_per_timeout + jitter) * recent_timeouts

  where jitter is some random number between 0 and max_jitter.

  ### Example Configuration

      config :ethereum_jsonrpc, EthereumJSONRPC.RequestCoordinator,
        rolling_window_opts: [
          window_count: 6,
          duration: :timer.seconds(10),
          table: EthereumJSONRPC.RequestCoordinator.TimeoutCounter
        ],
        wait_per_timeout: :timer.seconds(10),
        max_jitter: :timer.seconds(1)

  With this configuration, timeouts are tracked for 6 windows of 10 seconds for a total of 1 minute.
  """

  alias EthereumJSONRPC.{RollingWindow, Transport}

  @error_key :throttleable_error_count

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

      request
      |> transport.json_rpc(transport_options)
      |> handle_transport_response()
    else
      {:error, :timeout}
    end
  end

  defp handle_transport_response({:error, {:bad_gateway, _}} = error) do
    RollingWindow.inc(table(), @error_key)
    error
  end

  defp handle_transport_response({:error, :timeout} = error) do
    RollingWindow.inc(table(), @error_key)
    error
  end

  defp handle_transport_response(response), do: response

  defp sleep_time do
    wait_coefficient = RollingWindow.count(table(), @error_key)
    jitter = :rand.uniform(config(:max_jitter))
    wait_per_timeout = config(:wait_per_timeout)

    wait_coefficient * (wait_per_timeout + jitter)
  end

  defp table do
    :rolling_window_opts
    |> config()
    |> Keyword.fetch!(:table)
  end

  defp config(key) do
    :ethereum_jsonrpc
    |> Application.get_env(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
