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
      send(test_process, :request_received)
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
    test "reuses the pooled connection instead of opening one per request", %{url: url} do
      assert {:ok, %{status_code: 200}} = HttpClient.get(url)
      assert_received :request_received

      assert {:ok, %{status_code: 200}} = HttpClient.get(url)
      assert_received :request_received

      # the second request was served over the connection the first one opened,
      # which is what makes it skip DNS and the TCP + TLS handshake
      assert_received {:connection_reused, HttpClient.Finch}
    end
  end

  describe "proxy_get/3" do
    test "uses the Finch instance reserved for long-running requests", %{url: url} do
      assert {:ok, %{status_code: 200}} = HttpClient.proxy_get(url)
      assert {:ok, %{status_code: 200}} = HttpClient.proxy_get(url)
      assert_received {:connection_reused, HttpClient.ProxyFinch}

      # nothing went through the pool that serves the latency-critical preloads
      refute_received {:connection_reused, HttpClient.Finch}
    end
  end

  describe "pool_child_specs/0" do
    test "starts both Finch instances, sized from the MICROSERVICE_HTTP_POOL_SIZE configuration", %{url: url} do
      max_connections = Application.get_env(:explorer, :microservice_http_pool_size)

      # pools are started lazily per origin, so make one request through each
      assert {:ok, %{status_code: 200}} = HttpClient.get(url)
      assert {:ok, %{status_code: 200}} = HttpClient.proxy_get(url)

      for finch_name <- [HttpClient.Finch, HttpClient.ProxyFinch] do
        assert {:ok, [%Finch.HTTP1.PoolMetrics{pool_size: ^max_connections}]} =
                 Finch.get_pool_status(finch_name, url)
      end
    end
  end
end
