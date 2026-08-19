# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.MicroserviceInterfaces.HttpClientTest do
  use ExUnit.Case, async: false

  alias Explorer.MicroserviceInterfaces.HttpClient
  alias Plug.Conn

  @reuse_event [:finch, :reused_connection]

  setup do
    bypass = Bypass.open()
    test_process = self()

    # a stub rather than an expectation: not every test here makes a request,
    # and the ones that do assert on :request_received themselves
    Bypass.stub(bypass, "GET", "/api/v1/metadata", fn conn ->
      conn = Conn.fetch_query_params(conn)

      if conn.query_params["sleep"] do
        send(test_process, :slow_request_started)
        Process.sleep(300)
      else
        send(test_process, :request_received)
      end

      Conn.resp(conn, 200, "{}")
    end)

    handler_id = {__MODULE__, self()}

    :telemetry.attach(
      handler_id,
      @reuse_event,
      fn @reuse_event, _measurements, metadata, _config -> send(test_process, {:connection_reused, metadata.name}) end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach(handler_id)
      Bypass.down(bypass)
    end)

    {:ok, url: "http://localhost:#{bypass.port}/api/v1/metadata"}
  end

  describe "get/3" do
    test "reuses pooled connections instead of opening one per request", %{url: url} do
      # one more sequential request than there are pools, so at least one pool
      # must serve a second request over the connection its first one opened -
      # which is what makes reuse skip DNS and the TCP + TLS handshake
      for _ <- 1..(pool_count() + 1) do
        assert {:ok, %{status_code: 200}} = HttpClient.get(url)
        assert_received :request_received
      end

      assert_received {:connection_reused, HttpClient.Finch}
    end
  end

  describe "get/3 on a saturated pool" do
    test "returns an error tuple instead of raising, so preloads can degrade", %{url: url} do
      # a Finch instance with exactly one connection, so a single in-flight
      # request saturates it
      start_supervised!({Finch, name: __MODULE__.TinyFinch, pools: %{default: [size: 1, count: 1]}})

      slow_response =
        Task.async(fn -> HttpClient.get(url <> "?sleep=true", [], finch_instance: __MODULE__.TinyFinch) end)

      # wait until the slow request holds the pool's only connection
      assert_receive :slow_request_started, 1_000

      assert {:error, %RuntimeError{message: message}} =
               HttpClient.get(url, [], finch_instance: __MODULE__.TinyFinch, checkout_timeout: 50)

      assert message =~ "excess queuing"

      assert {:ok, %{status_code: 200}} = Task.await(slow_response)
    end
  end

  describe "proxy_get/3" do
    test "uses the Finch instance reserved for long-running requests", %{url: url} do
      for _ <- 1..(pool_count() + 1) do
        assert {:ok, %{status_code: 200}} = HttpClient.proxy_get(url)
      end

      assert_received {:connection_reused, HttpClient.ProxyFinch}

      # nothing went through the instance that serves the latency-critical
      # preloads
      refute_received {:connection_reused, HttpClient.Finch}
    end
  end

  describe "pool_child_specs/0" do
    test "starts both Finch instances, with MICROSERVICE_HTTP_POOL_SIZE connections split across MICROSERVICE_HTTP_POOL_COUNT pools",
         %{url: url} do
      total_size = Application.get_env(:explorer, :microservice_http_pool_size)
      pool_count = pool_count()
      per_pool_size = div(total_size, pool_count)

      # pools are started lazily per origin, so make one request through each
      assert {:ok, %{status_code: 200}} = HttpClient.get(url)
      assert {:ok, %{status_code: 200}} = HttpClient.proxy_get(url)

      for finch_name <- [HttpClient.Finch, HttpClient.ProxyFinch] do
        assert {:ok, pool_metrics} = Finch.get_pool_status(finch_name, url)
        assert length(pool_metrics) == pool_count
        assert Enum.all?(pool_metrics, &(&1.pool_size == per_pool_size))
      end
    end
  end

  defp pool_count, do: Application.get_env(:explorer, :microservice_http_pool_count)
end
