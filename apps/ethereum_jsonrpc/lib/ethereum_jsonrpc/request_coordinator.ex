defmodule EthereumJSONRPC.RequestCoordinator do
  @moduledoc """
  Retries JSONRPC requests according to the provided retry_options

  Leverages `EthereumJSONRPC.RollingWindow` to keep track of the count
  of recent timeouts, and waits a small amount of time per timeout.

  To see the rolling window options, see `EthereumJSONRPC.Application`
  """
  alias EthereumJSONRPC.{RollingWindow, TimeoutCounter}

  @wait_per_timeout :timer.seconds(5)
  @rolling_window_opts [
    bucket: :ethereum_jsonrpc_bucket,
    window_length: :timer.seconds(10),
    window_count: 6
  ]

  @doc "Options used when initializing the RollingWindow used by this module."
  @spec rolling_window_opts() :: Keyword.t()
  def rolling_window_opts do
    @rolling_window_opts
  end

  @doc """
  Retries the request according to the provided retry_options

  If none were provided, the request is not retried. In all cases, the request
  waits an amount of time before proceeding based on the count of recent
  failures.
  """
  @spec perform(term(), )
  def perform(request, named_arguments) do
    transport = Keyword.fetch!(named_arguments, :transport)
    transport_options = Keyword.fetch!(named_arguments, :transport_options)
    retry_options = Keyword.get(named_arguments, :retry_options)

    if retry_options do
      retry_timeout = Keyword.get(retry_options, :retry_timeout, 5_000)

      fn ->
        request(transport, request, transport_options, true)
      end
      |> Task.async()
      |> Task.await(retry_timeout)
    else
      request(transport, request, transport_options, false)
    end
  end

  defp request(transport, request, transport_options, retry?) do
    key = something_that_uniquely_identifies_this_transport(transport, transport_options)

    sleep_if_too_many_recent_timeouts(key)

    case request(transport, request, transport_options) do
      {:error, :timeout} = error ->
        increment_recent_timeouts(key)

        if retry? do
          request_with_retry(transport, request, transport_options)
        else
          error
        end

      response ->
        response
    end
  end

  defp increment_recent_timeouts(key) do
    RollingWindow.inc(TimeoutCounter, key)

    :ok
  end

  defp sleep_if_too_many_recent_timeouts(key) do
    wait_coefficient = count_of_recent_timeouts(key)

    :timer.sleep(wait_coefficient * @wait_per_timeout)
  end

  defp something_that_uniquely_identifies_this_transport(transport, transport_options) do
    to_string(transport) <> "." <> transport_options[:url]
  end

  defp count_of_recent_timeouts(key) do
    RollingWindow.count(TimeoutCounter, key)
  end
end
