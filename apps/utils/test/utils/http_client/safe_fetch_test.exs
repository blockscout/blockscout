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

  test "passes headers and transport_opts through unchanged for an IP literal host" do
    parent = self()

    t = fn url, headers, opts ->
      send(parent, {:requested, url, headers, opts})
      {:ok, resp(200, [], "ok")}
    end

    assert {:ok, %{status_code: 200}} = SafeFetch.request(@public, [{"Accept", "*/*"}], [transport_opts: [a: 1]], t)
    assert_received {:requested, @public, [{"Accept", "*/*"}], [a: 1]}
  end

  describe "DNS pinning" do
    # A rebinding host: a nameserver under the attacker's control answers the lookup made
    # by the validation with a public address and the next one with an internal address.
    setup do
      start_fake_nameserver([{8, 8, 8, 8}, {127, 0, 0, 1}])
      :ok
    end

    test "connects to the validated address instead of resolving the host again" do
      parent = self()

      t = fn url, headers, opts ->
        send(parent, {:requested, url, headers, opts})
        {:ok, resp(200, [], "ok")}
      end

      assert {:ok, %{status_code: 200}} =
               SafeFetch.request("http://rebind.test/meta", [{"Accept", "*/*"}], [transport_opts: [a: 1]], t)

      assert_received {:requested, "http://8.8.8.8/meta", [{"Host", "rebind.test"}, {"Accept", "*/*"}],
                       [hostname: "rebind.test", a: 1]}

      # What the HTTP client would have gotten had it resolved the host itself.
      assert DNS.resolve("rebind.test", :a) == {:ok, [{127, 0, 0, 1}]}
    end

    test "keeps scheme, non-default port, path and query" do
      parent = self()

      t = fn url, headers, opts ->
        send(parent, {:requested, url, headers, opts})
        {:ok, resp(200, [], "ok")}
      end

      assert {:ok, _} = SafeFetch.request("https://rebind.test:8443/a/b?x=1", [], [], t)

      assert_received {:requested, "https://8.8.8.8:8443/a/b?x=1", [{"Host", "rebind.test:8443"}],
                       [hostname: "rebind.test"]}
    end

    test "pins redirect targets as well" do
      t =
        transport(fn
          "http://8.8.8.8/first" -> {:ok, resp(302, [{"location", "http://rebind.test/second"}])}
        end)

      # The second lookup of the rebinding host answers with the internal address.
      assert SafeFetch.request("http://rebind.test/first", [], [], t) == {:error, :blacklist}
      refute_received {:requested, "http://rebind.test/second"}
      refute_received {:requested, "http://127.0.0.1/second"}
    end
  end

  describe "DNS pinning of an IPv6-only host" do
    setup do
      start_fake_nameserver([{0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111}])
      :ok
    end

    test "connects to the bracketed address over an IPv6 socket" do
      parent = self()

      t = fn url, headers, opts ->
        send(parent, {:requested, url, headers, opts})
        {:ok, resp(200, [], "ok")}
      end

      assert {:ok, %{status_code: 200}} = SafeFetch.request("http://rebind.test/meta", [], [], t)

      assert_received {:requested, "http://[2606:4700:4700::1111]/meta", [{"Host", "rebind.test"}],
                       [hostname: "rebind.test", inet6: true]}
    end
  end

  describe "DNS pinning of a host with several addresses" do
    setup do
      start_fake_nameserver([[{:a, {8, 8, 8, 8}}, {:a, {1, 1, 1, 1}}, {:a, {9, 9, 9, 9}}]])
      :ok
    end

    test "moves to the next validated address when the connection fails" do
      t =
        transport(fn
          "http://8.8.8.8/meta" -> {:error, :econnrefused}
          "http://1.1.1.1/meta" -> {:error, %{reason: :ehostunreach}}
          "http://9.9.9.9/meta" -> {:ok, resp(200, [], "ok")}
        end)

      assert {:ok, %{status_code: 200}} = SafeFetch.request("http://multi.test/meta", [], [], t)
      assert_received {:requested, "http://8.8.8.8/meta"}
      assert_received {:requested, "http://1.1.1.1/meta"}
      assert_received {:requested, "http://9.9.9.9/meta"}
    end

    test "returns the last error when every address fails to connect" do
      t = transport(fn _url -> {:error, :econnrefused} end)

      assert SafeFetch.request("http://multi.test/meta", [], [], t) == {:error, :econnrefused}
      assert_received {:requested, "http://9.9.9.9/meta"}
    end

    test "does not retry an error that is not a connection failure" do
      t = transport(fn "http://8.8.8.8/meta" -> {:error, :timeout} end)

      assert SafeFetch.request("http://multi.test/meta", [], [], t) == {:error, :timeout}
      refute_received {:requested, "http://1.1.1.1/meta"}
    end

    test "gives each attempt but the last half of the connection timeout that is left" do
      parent = self()

      t = fn url, _headers, opts ->
        send(parent, {:requested, url, opts[:timeout]})
        Process.sleep(10)
        {:error, :econnrefused}
      end

      assert SafeFetch.request("http://multi.test/meta", [], [transport_opts: [timeout: 60_000]], t) ==
               {:error, :econnrefused}

      assert_received {:requested, "http://8.8.8.8/meta", first}
      assert_received {:requested, "http://1.1.1.1/meta", second}
      assert_received {:requested, "http://9.9.9.9/meta", last}
      assert first in 29_990..30_000
      assert second in 20_000..29_995
      assert last in 40_000..59_980
    end

    test "shares a default budget when no connection timeout is given" do
      parent = self()

      t = fn url, _headers, opts ->
        send(parent, {:requested, url, opts[:timeout]})
        {:error, :econnrefused}
      end

      assert SafeFetch.request("http://multi.test/meta", [], [], t) == {:error, :econnrefused}

      assert_received {:requested, "http://8.8.8.8/meta", first}
      assert_received {:requested, "http://9.9.9.9/meta", last}
      assert first in 3_990..4_000
      assert last in 7_000..8_000
    end

    test "stops retrying once the connection timeout is spent" do
      t =
        transport(fn _url ->
          Process.sleep(50)
          {:error, :connect_timeout}
        end)

      assert SafeFetch.request("http://multi.test/meta", [], [transport_opts: [timeout: 50]], t) ==
               {:error, :connect_timeout}

      assert_received {:requested, "http://8.8.8.8/meta"}
      refute_received {:requested, "http://1.1.1.1/meta"}
    end
  end

  describe "DNS pinning of a host with IPv4 and IPv6 addresses" do
    setup do
      start_fake_nameserver([
        [{:a, {8, 8, 8, 8}}, {:a, {1, 1, 1, 1}}],
        {0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111}
      ])

      :ok
    end

    test "tries an IPv6 address when IPv4 connections stall" do
      parent = self()

      # An IPv4 connection that gets no answer takes the whole timeout it is given.
      t = fn url, _headers, opts ->
        send(parent, {:requested, url, opts[:timeout]})

        if opts[:inet6] do
          {:ok, resp(200, [], "ok")}
        else
          Process.sleep(opts[:timeout])
          {:error, :connect_timeout}
        end
      end

      assert {:ok, %{status_code: 200}} =
               SafeFetch.request("http://dual.test/meta", [], [transport_opts: [timeout: 200]], t)

      # The address families alternate, and the stalled attempt gets half of the budget.
      assert_received {:requested, "http://8.8.8.8/meta", stalled}
      assert stalled in 90..100
      assert_received {:requested, "http://[2606:4700:4700::1111]/meta", _timeout}
      refute_received {:requested, "http://1.1.1.1/meta", _timeout}
    end
  end

  describe "DNS pinning of a CNAME host" do
    # A resolver answers an A query for an alias with the CNAME record followed by the
    # address records of its target.
    setup do
      start_fake_nameserver([[{:cname, ~c"cdn.example.test"}, {:a, {8, 8, 8, 8}}]])
      :ok
    end

    test "pins the address record, not the alias target" do
      parent = self()

      t = fn url, headers, opts ->
        send(parent, {:requested, url, headers, opts})
        {:ok, resp(200, [], "ok")}
      end

      assert {:ok, %{status_code: 200}} = SafeFetch.request("http://alias.test/meta", [], [], t)
      assert_received {:requested, "http://8.8.8.8/meta", [{"Host", "alias.test"}], [hostname: "alias.test"]}
    end
  end

  # Starts a fake authoritative nameserver on 127.0.0.1 and puts it first in the resolver
  # list used by `DNS.resolve`. An answer is an IPv4 or IPv6 address, or a list of
  # `{type, data}` records; a query consumes the next answer when it holds a record of the
  # queried type (TTL 0, so nothing gets cached) and gets no records otherwise.
  defp start_fake_nameserver(answers) do
    parent = self()

    pid =
      spawn_link(fn ->
        {:ok, socket} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
        {:ok, port} = :inet.port(socket)
        send(parent, {:nameserver_port, port})
        serve_dns(socket, answers)
      end)

    port =
      receive do
        {:nameserver_port, port} -> port
      end

    # The first `:inet_res` query in the VM loads `/etc/resolv.conf` and replaces the
    # nameserver list with its content, which would drop the entry inserted below.
    :ok = :inet_db.res_update_conf()
    :ok = :inet_db.ins_ns({127, 0, 0, 1}, port)

    on_exit(fn ->
      :inet_db.del_ns({127, 0, 0, 1}, port)
      Process.exit(pid, :kill)
    end)
  end

  defp serve_dns(socket, answers) do
    {:ok, {ip, port, packet}} = :gen_udp.recv(socket, 0)
    {:ok, query} = :inet_dns.decode(packet)
    [question] = :inet_dns.msg(query, :qdlist)
    domain = :inet_dns.dns_query(question, :domain)
    type = :inet_dns.dns_query(question, :type)

    {records, rest} =
      case answers do
        [answer | rest] ->
          records = records(answer)
          if List.keymember?(records, type, 0), do: {records, rest}, else: {[], answers}

        [] ->
          {[], []}
      end

    anlist =
      Enum.map(records, fn {rr_type, data} ->
        :inet_dns.make_rr(domain: domain, type: rr_type, class: :in, ttl: 0, data: data)
      end)

    header = :inet_dns.make_header(:inet_dns.msg(query, :header), qr: true, aa: true)
    response = :inet_dns.make_msg(header: header, qdlist: [question], anlist: anlist)
    :ok = :gen_udp.send(socket, ip, port, :inet_dns.encode(response))
    serve_dns(socket, rest)
  end

  defp records(address) when tuple_size(address) == 4, do: [{:a, address}]
  defp records(address) when tuple_size(address) == 8, do: [{:aaaa, address}]
  defp records(records) when is_list(records), do: records
end
