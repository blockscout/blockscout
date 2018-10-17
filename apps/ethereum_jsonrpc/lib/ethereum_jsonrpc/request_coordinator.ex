defmodule EthereumJSONRPC.RequestCoordinator do
  @failure_rate_limit_interval :timer.minutes(3)
  @failure_rate_limit 30

  def perform(request, named_arguments) do
    transport = Keyword.fetch!(named_arguments, :transport)
    transport_options = Keyword.fetch!(named_arguments, :transport_options)
    retry_options = Keyword.get(named_arguments, :retry_options)

    if retry_options do
      retry_timeout = Keyword.get(retry_options, :retry_timeout, 5_000)

      fn ->
        request_with_retry(transport, request, transport_options)
      end
      |> Task.async()
      |> Task.await()
    else
      request(transport, request, transport_options)
    end
  end

  defp request_with_retry(transport, request, transport_options) do
    key = something_that_uniquely_identifies_this_transport(transport, transport_options)

    sleep_if_too_many_recent_timeouts(key)

    case request(transport, request, transport_options) do
      {:error, :timeout} ->
        increment_recent_timeouts(key)

        request_with_retry(transport, request, transport_options)

      response ->
        response
    end
  end

  defp request(transport, request, transport_options), do: transport.json_rpc(request, transport_options)

  @spec increment_recent_timeouts(String.t()) :: :ok
  defp increment_recent_timeouts(key) do
    # TODO: Call into rolling window rate limiter
    # ExRated.check_rate(key, @failure_rate_limit_interval, @failure_rate_limit)

    :ok
  end

  defp sleep_if_too_many_recent_timeouts(key) do
    wait_coefficient = count_of_recent_timeouts(key)

    # TODO: Math TBD
    :timer.sleep(:timer.seconds(wait_coefficient))
  end

  defp something_that_uniquely_identifies_this_transport(transport, transport_options) do
    to_string(transport) <> "." <> transport_options[:url]
  end

  defp count_of_recent_timeouts(key) do
    # if we are using ex_rated it looks like this:
    # TODO: Call into rolling window rate limiter
    # {count, _count_remaining, _ms_to_next_bucket, _created_at, _updated_at} =
    #   ExRated.inspect_bucket(key, @failure_rate_limit_interval, @failure_rate_limit)

    count
  end
end
