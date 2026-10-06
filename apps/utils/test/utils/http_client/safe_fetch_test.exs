# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.HttpClient.SafeFetchTest do
  use ExUnit.Case, async: false

  alias Utils.HttpClient.SafeFetch

  @public "http://8.8.8.8/"
  @internal "http://127.0.0.1/"

  setup do
    previous = Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)

    put_config(host_filtering_enabled?: true)

    on_exit(fn ->
      Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, previous)
      :persistent_term.erase(:parsed_cidr_list)
    end)

    :ok
  end

  defp put_config(overrides) do
    base = [host_filtering_enabled?: true, cidr_blacklist: [], allowed_uri_protocols: ["http", "https"]]
    Application.put_env(:indexer, Indexer.Fetcher.TokenInstance.Helper, Keyword.merge(base, overrides))
    :persistent_term.erase(:parsed_cidr_list)
  end

  defp resp(status, headers, body \\ ""), do: %{status_code: status, headers: headers, body: body}

  # Builds an arity-3 transport that records each requested URL to the test process
  # and delegates to `responder` for the canned response.
  defp transport(responder) do
    parent = self()

    fn url, _headers, _opts ->
      send(parent, {:requested, url})
      responder.(url)
    end
  end

  test "rejects a blacklisted initial url without issuing the request" do
    t = transport(fn _ -> flunk("transport must not be called for a blacklisted host") end)
    assert SafeFetch.request(@internal, [], [], t) == {:error, :blacklist}
  end

  test "rejects a redirect to an internal address (per-hop validation)" do
    t =
      transport(fn
        @public -> {:ok, resp(302, [{"Location", @internal}])}
      end)

    assert SafeFetch.request(@public, [], [], t) == {:error, :blacklist}
    assert_received {:requested, @public}
    refute_received {:requested, @internal}
  end

  test "follows a redirect to a public address" do
    t =
      transport(fn
        @public -> {:ok, resp(302, [{"location", "http://1.1.1.1/next"}])}
        "http://1.1.1.1/next" -> {:ok, resp(200, [], "ok")}
      end)

    assert {:ok, %{status_code: 200, body: "ok"}} = SafeFetch.request(@public, [], [], t)
  end

  test "resolves a relative Location against the current url and re-validates it" do
    t =
      transport(fn
        "http://8.8.8.8/a/b" -> {:ok, resp(302, [{"location", "/c"}])}
        "http://8.8.8.8/c" -> {:ok, resp(200, [], "ok")}
      end)

    assert {:ok, %{status_code: 200}} = SafeFetch.request("http://8.8.8.8/a/b", [], [], t)
    assert_received {:requested, "http://8.8.8.8/a/b"}
    assert_received {:requested, "http://8.8.8.8/c"}
  end

  test "stops after max redirects" do
    t = transport(fn url -> {:ok, resp(302, [{"location", url}])} end)
    assert SafeFetch.request(@public, [], [max_redirects: 3], t) == {:error, :too_many_redirects}
  end

  test "returns a non-redirect response as-is" do
    t = transport(fn @public -> {:ok, resp(200, [], "body")} end)
    assert {:ok, %{status_code: 200, body: "body"}} = SafeFetch.request(@public, [], [], t)
  end

  test "returns a 3xx without a Location header as-is" do
    t = transport(fn @public -> {:ok, resp(302, [])} end)
    assert {:ok, %{status_code: 302}} = SafeFetch.request(@public, [], [], t)
  end

  test "skips validation of the initial url when validate_host? is false" do
    t = transport(fn @internal -> {:ok, resp(200, [], "ok")} end)
    assert {:ok, %{status_code: 200}} = SafeFetch.request(@internal, [], [validate_host?: false], t)
  end

  test "still validates redirect targets when validate_host? is false" do
    # The initial host is exempt (operator-configured gateway), but a host it redirects to
    # is not, so the internal target must be rejected without being requested.
    t =
      transport(fn
        "http://10.0.0.1/gateway" -> {:ok, resp(302, [{"location", @internal}])}
      end)

    assert SafeFetch.request("http://10.0.0.1/gateway", [], [validate_host?: false], t) ==
             {:error, :blacklist}

    assert_received {:requested, "http://10.0.0.1/gateway"}
    refute_received {:requested, @internal}
  end

  test "rejects a redirect to a disallowed scheme when validate_host? is false" do
    t =
      transport(fn
        "http://10.0.0.1/gateway" -> {:ok, resp(302, [{"location", "ftp://8.8.8.8/x"}])}
      end)

    assert SafeFetch.request("http://10.0.0.1/gateway", [], [validate_host?: false], t) ==
             {:error, :disallowed_protocol}

    refute_received {:requested, "ftp://8.8.8.8/x"}
  end

  test "skips validation when host filtering is globally disabled" do
    put_config(host_filtering_enabled?: false)
    t = transport(fn @internal -> {:ok, resp(200, [], "ok")} end)
    assert {:ok, %{status_code: 200}} = SafeFetch.request(@internal, [], [], t)
  end

  test "propagates transport errors" do
    t = transport(fn @public -> {:error, :econnrefused} end)
    assert SafeFetch.request(@public, [], [], t) == {:error, :econnrefused}
  end
end
