# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.MicroserviceInterfaces.HttpClient do
  @moduledoc """
  HTTP client for requests to Blockscout microservices.

  Microservice requests sit on the critical path of API responses and are made
  over and over to the same handful of hosts. The default client configured in
  `:explorer, :http_client` uses `Tesla.Adapter.Mint`, which opens a connection
  for every request and closes it once the response is read, so every call pays
  for DNS resolution and a TCP + TLS handshake. Measured against a microservice
  answering in ~30ms at the origin, that overhead dominates the call.

  This module routes microservice requests through Finch (mint connections kept
  alive in a `NimblePool`), so connections are reused across requests. hackney
  was avoided deliberately: it leaked binaries in production before. The Finch
  instances are started in `Explorer.Application`.

  Two Finch instances are used, because the workloads have very different
  shapes:

    * `#{inspect(__MODULE__)}.Finch` for short requests on the critical path of
      an API response, such as the ENS and metadata preloads. These get a short
      pool (checkout) timeout: when the pool is saturated it is better to answer
      without the decorative data than to make the caller queue for a
      connection.

    * `#{inspect(__MODULE__)}.ProxyFinch` for requests proxied to a microservice
      on behalf of an API caller, which are allowed to run for much longer (see
      `MICROSERVICE_METADATA_PROXY_REQUESTS_TIMEOUT`). Sharing a pool with the
      preloads would let a handful of these hold connections for tens of seconds
      and starve them.
  """

  @finch_name __MODULE__.Finch
  @proxy_finch_name __MODULE__.ProxyFinch

  # Milliseconds a request waits for a free connection. A preload that has to
  # queue has already lost the latency it was trying to save, so it gives up
  # quickly and the response is rendered without the extra data.
  @checkout_timeout 500
  @proxy_checkout_timeout :timer.seconds(5)

  @doc """
  Sends a pooled GET request. Accepts the same options as `Explorer.HttpClient.get/3`.
  """
  @spec get(binary(), list(), keyword()) :: {:ok, map()} | {:error, any()}
  def get(url, headers \\ [], options \\ []) do
    request(:get, url, nil, headers, options, @finch_name, @checkout_timeout)
  end

  @doc """
  Sends a pooled POST request. Accepts the same options as `Explorer.HttpClient.post/4`.
  """
  @spec post(binary(), iodata(), list(), keyword()) :: {:ok, map()} | {:error, any()}
  def post(url, body, headers \\ [], options \\ []) do
    request(:post, url, body, headers, options, @finch_name, @checkout_timeout)
  end

  @doc """
  Sends a GET request proxied on behalf of an API caller, through the Finch
  instance reserved for long-running microservice requests.
  """
  @spec proxy_get(binary(), list(), keyword()) :: {:ok, map()} | {:error, any()}
  def proxy_get(url, headers \\ [], options \\ []) do
    request(:get, url, nil, headers, options, @proxy_finch_name, @proxy_checkout_timeout)
  end

  @doc """
  Returns the child specs of the Finch instances used for microservice requests.
  """
  @spec pool_child_specs() :: [Supervisor.child_spec()]
  def pool_child_specs do
    total_size = Application.get_env(:explorer, :microservice_http_pool_size)
    pool_count = Application.get_env(:explorer, :microservice_http_pool_count)

    pools = %{
      default: [
        # NimblePool is built for small pools, and per-pool size is the knob
        # that keeps its process responsive. Two costs scale with it: every
        # checkout/checkin is a message through the single pool process, and -
        # much worse - every message an idle socket sends it (e.g. the remote
        # closing an idle keep-alive connection) makes NimblePool run
        # handle_info over EVERY idle worker, O(size) per message. A batch of
        # idle-connection closes against a big pool can occupy its process for
        # long enough that checkout replies miss the pool timeout even though
        # almost all connections are free. Keep per-pool size around Finch's
        # default of 50 by raising MICROSERVICE_HTTP_POOL_COUNT rather than
        # letting pools grow.
        size: max(div(total_size, pool_count), 1),
        count: pool_count,
        # metrics make the pools observable in a remote console via
        # Finch.get_pool_status/2, e.g. when debugging checkout timeouts
        start_pool_metrics?: true
      ]
    }

    Enum.map([@finch_name, @proxy_finch_name], &Finch.child_spec(name: &1, pools: pools))
  end

  defp request(method, url, body, headers, options, finch_name, default_checkout_timeout) do
    # :finch_instance is a test seam: it lets tests exercise this function
    # against a small pool they control instead of the app-wide instances
    adapter_options =
      [
        name: options[:finch_instance] || finch_name,
        pool_timeout: options[:checkout_timeout] || default_checkout_timeout
      ]
      |> put_receive_timeout(options[:recv_timeout])

    [method: method, url: url, body: body, headers: headers, query: options[:params] || []]
    |> then(&Tesla.request(client(adapter_options), &1))
    |> parse_response()
  rescue
    # Finch raises when no connection frees up within the pool timeout (and for
    # little else). Callers expect the hackney-era contract where a saturated
    # pool is an {:error, _} to log and degrade on - a response without ENS
    # names or tags - not an exception that kills the API request.
    exception in RuntimeError -> {:error, exception}
  catch
    # other pool checkout failures (e.g. the pool process going down) exit
    # instead of raising; degrade the same way
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp client(adapter_options) do
    Tesla.client([], {Tesla.Adapter.Finch, adapter_options})
  end

  defp put_receive_timeout(adapter_options, nil), do: adapter_options

  defp put_receive_timeout(adapter_options, recv_timeout) do
    Keyword.put(adapter_options, :receive_timeout, recv_timeout)
  end

  defp parse_response({:ok, %Tesla.Env{body: body, status: status_code, headers: headers}}) do
    {:ok, %{body: body, status_code: status_code, headers: headers}}
  end

  defp parse_response(error), do: error
end
