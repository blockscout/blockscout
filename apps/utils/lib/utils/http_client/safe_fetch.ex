# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.HttpClient.SafeFetch do
  @moduledoc """
  Performs an HTTP request against an attacker-controlled URL while validating the
  host (and every redirect target) against `Utils.UrlValidator`.

  Neither `Tesla.Middleware.FollowRedirects` nor hackney exposes a per-redirect hook,
  so redirects are followed manually here: the request is issued with automatic
  redirect-following disabled, and each `Location` is re-validated before the next hop.

  A validated host is also pinned: the request is issued against the IP addresses that
  passed validation rather than against the hostname, so the HTTP client does not resolve
  the host a second time (DNS rebinding). The addresses are tried in turn while connecting
  fails, alternating IPv4 and IPv6, within one connection timeout for all of them. See
  `pin/2` and `try_each/4`.

  The concrete HTTP client is injected as a `transport` closure of arity 3
  (`url, headers, transport_opts -> {:ok, response} | {:error, term}`), so this module
  stays transport-agnostic and callers keep using their existing client
  (`Explorer.HttpClient` for the Tesla path, `HTTPoison` for the media paths). The
  response is returned verbatim, so callers can keep pattern-matching on their client's
  native shape (`%HTTPoison.Response{}` or the `Explorer.HttpClient`-normalized map).
  """

  alias Utils.UrlValidator

  @default_max_redirects 5
  @redirect_statuses [301, 302, 303, 307, 308]

  # Errors of establishing the connection, after which the next validated address is tried:
  # what `gen_tcp:connect/4` reports for an address that refuses, cannot be reached or does
  # not answer, plus hackney's own `:connect_timeout`. The timeouts hackney and Mint report
  # themselves are recognised in `connect_error?/1`.
  @connect_errors [
    :econnrefused,
    :ehostunreach,
    :enetunreach,
    :enetdown,
    :etimedout,
    :eafnosupport,
    :eaddrnotavail,
    :connect_timeout
  ]

  # Budget for the attempts when the caller sets no connection timeout: hackney's default
  # connect timeout. Mint's is 30 s, so a caller on the Tesla transport should set one.
  @default_connect_timeout 8_000

  # The smallest connection timeout worth an attempt (the minimum connection attempt delay of
  # RFC 8305, section 5): the budget is not split below it, and no attempt is made once less
  # than it is left.
  @min_connect_timeout 100

  @type transport :: (String.t(), list(), keyword() -> {:ok, term()} | {:error, term()})

  @doc """
  Validates `url`, issues the request via `transport` with redirects disabled, and
  manually follows up to `:max_redirects` redirects, validating each target.

  ## Options
  - `:validate_host?` (default `true`) — whether to validate the host of the **initial**
    request. Pass `false` for a URL already resolved to an operator-configured gateway
    (IPFS/Arweave/Swarm), which may legitimately live on a private address. Redirect
    targets are validated regardless, since the operator does not choose those. Host
    filtering is additionally gated by the global `host_filtering_enabled?` flag.
  - `:max_redirects` (default `#{@default_max_redirects}`) — maximum number of redirect hops.
  - `:transport_opts` — options passed straight to the `transport` closure (e.g.
    `recv_timeout`, `max_body_length`, `pool`). Must NOT enable automatic redirect
    following. `timeout`, the connection timeout, is also the budget for trying all the
    addresses of a pinned host (see below); without it `#{@default_connect_timeout}` ms is
    used, which is hackney's default but shorter than Mint's.

  When the host was validated, the `transport` receives the URL with the host replaced by
  a validated IP address (the next one on each connection failure), a `Host` header for the
  original host and a `:hostname` entry in `transport_opts` (plus `inet6: true` for an IPv6
  address).
  `Utils.HttpClient.TeslaHelper.request_opts/1` and `Utils.HttpClient.HTTPoisonHelper.request_opts/1`
  turn these into the client's SNI, certificate-verification and socket options, so a
  transport must build its options through one of them.

  Returns the transport's `{:ok, response}` for the final (non-redirect) hop, or
  `{:error, reason}` — including `{:error, :too_many_redirects}` and
  `{:error, :invalid_redirect_location}`.
  """
  @spec request(String.t(), list(), keyword(), transport()) :: {:ok, term()} | {:error, term()}
  def request(url, headers, opts, transport) when is_function(transport, 3) do
    do_request(
      url,
      headers,
      opts,
      transport,
      Keyword.get(opts, :max_redirects, @default_max_redirects),
      Keyword.get(opts, :validate_host?, true)
    )
  end

  defp do_request(url, headers, opts, transport, hops_left, validate_host?) do
    with {:ok, requests} <- maybe_validate(url, validate_host?),
         {:ok, response} <- try_each(requests, headers, opts, transport) do
      case redirect_target(response, url) do
        :none ->
          {:ok, response}

        # Redirect targets are always validated, even when the initial host was exempt: an
        # operator-configured gateway is trusted because the operator chose it, but the host
        # it redirects to is not something the operator chose.
        {:ok, next_url} when hops_left > 0 ->
          do_request(next_url, headers, opts, transport, hops_left - 1, true)

        {:ok, _next_url} ->
          {:error, :too_many_redirects}

        :error ->
          {:error, :invalid_redirect_location}
      end
    end
  end

  # Returns the requests to issue, each as `{url, headers, transport_opts}` to prepend to
  # the caller's: one pinned request per validated address (see `pin/2`) when the host was
  # validated, the URL as-is otherwise.
  defp maybe_validate(url, true) do
    if host_filtering_enabled?() do
      with {:ok, ip_list} <- UrlValidator.validate_and_resolve_uri(url), do: {:ok, pin(url, ip_list)}
    else
      {:ok, [{url, [], []}]}
    end
  end

  defp maybe_validate(url, false), do: {:ok, [{url, [], []}]}

  # Issues the requests in turn: a failure to connect moves on to the next address, as the
  # HTTP client does when it resolves the host itself; any other error, and the error of the
  # last address, is returned as-is. The caller's connection timeout (`:timeout` in
  # `transport_opts`, `@default_connect_timeout` when it is not set) is one budget for all
  # attempts, and each attempt but the last gets half of what is left of it, though not less
  # than `@min_connect_timeout`. An address that does not answer therefore cannot use up the
  # budget before the next one, of the other address family (see `alternate_families/1`), is
  # tried: hackney raced the families when it resolved the host itself. A single request is
  # issued with the caller's options as they are.
  defp try_each([request], headers, opts, transport) do
    issue(request, headers, Keyword.get(opts, :transport_opts, []), transport)
  end

  defp try_each(requests, headers, opts, transport) do
    transport_opts = Keyword.get(opts, :transport_opts, [])
    try_in_turn(requests, headers, transport_opts, transport, deadline(transport_opts[:timeout]))
  end

  defp try_in_turn([request | rest], headers, transport_opts, transport, deadline) do
    left = deadline - System.monotonic_time(:millisecond)
    timeout = if rest == [], do: left, else: left |> div(2) |> max(@min_connect_timeout) |> min(left)

    case issue(request, headers, Keyword.put(transport_opts, :timeout, timeout), transport) do
      {:error, error} = result ->
        left = deadline - System.monotonic_time(:millisecond)

        if rest != [] and connect_error?(error) and left >= @min_connect_timeout do
          try_in_turn(rest, headers, transport_opts, transport, deadline)
        else
          result
        end

      result ->
        result
    end
  end

  defp issue({connect_url, pin_headers, pin_opts}, headers, transport_opts, transport) do
    transport.(connect_url, pin_headers ++ headers, pin_opts ++ transport_opts)
  end

  defp deadline(timeout) when is_integer(timeout), do: System.monotonic_time(:millisecond) + timeout
  defp deadline(_timeout), do: deadline(@default_connect_timeout)

  # hackney reports a bare atom (wrapped in `%HTTPoison.Error{}` by HTTPoison), Mint a
  # `%Mint.TransportError{}`. Both report a stalled connection as `:timeout`, which is also
  # what a response timeout looks like, so the transport tells the two apart:
  # - `Tesla.Adapter.Mint` returns the error of `Mint.HTTP.connect/4` as it is and turns a
  #   response timeout into a bare `:timeout`, so a `:timeout` in the struct is a connection
  #   timeout. Mint is not a dependency of this application, hence the map pattern.
  # - hackney returns the `:timeout` of its plain `gen_tcp`/`ssl` connect to an IP literal as
  #   it is, and so does its response timeout. Within the connection budget it is taken for a
  #   stalled connection: `SafeFetch` serves GET and HEAD requests, so at worst an idempotent
  #   request is repeated at the next address.
  # A bare `:timeout` is a response timeout of the Tesla transport, or any timeout of a
  # transport that unwraps the client's error (`Explorer.HttpClient.HTTPoison`), and is final.
  defp connect_error?(%{__struct__: Mint.TransportError, reason: :timeout}), do: true
  defp connect_error?(%HTTPoison.Error{reason: :timeout}), do: true
  defp connect_error?(%{reason: reason}), do: reason in @connect_errors
  defp connect_error?(reason), do: reason in @connect_errors

  # The HTTP client resolves the hostname again when it connects, and nothing ties that
  # lookup to the one that was validated: a DNS record under the attacker's control can
  # answer with a public address first and an internal one next (DNS rebinding). So the
  # request goes to the validated address instead: the URL host becomes the IP literal,
  # while the original host is sent in the `Host` header and passed as the `:hostname`
  # transport option, from which the transport helpers derive SNI and certificate
  # verification. A host that is already an IP literal is left untouched.
  defp pin(url, ip_list) do
    uri = URI.parse(url)

    if ip_literal?(uri.host) do
      [{url, [], []}]
    else
      ip_list
      |> alternate_families()
      |> Enum.map(fn ip ->
        connect_url = URI.to_string(%{uri | host: ip |> :inet.ntoa() |> to_string()})
        {connect_url, [{"Host", host_header(uri)}], pin_opts(uri.host, ip)}
      end)
    end
  end

  # Orders the addresses IPv4 and IPv6 in turn, so that when one address family does not
  # answer, the other one is tried next (RFC 8305, section 4). IPv4 goes first, unlike in the
  # RFC: IPv6 that is routed but black-holed is common enough in deployments not to spend half
  # of the budget on it before an IPv4 address is tried.
  defp alternate_families(ip_list) do
    {ipv4, ipv6} = Enum.split_with(ip_list, &(tuple_size(&1) == 4))
    alternate(ipv4, ipv6)
  end

  defp alternate([ipv4 | ipv4_rest], [ipv6 | ipv6_rest]), do: [ipv4, ipv6 | alternate(ipv4_rest, ipv6_rest)]
  defp alternate(ipv4, ipv6), do: ipv4 ++ ipv6

  # An IPv6 literal needs an IPv6 socket, which the Tesla/Mint transport opens only when asked.
  defp pin_opts(host, ip) when tuple_size(ip) == 8, do: [hostname: host, inet6: true]
  defp pin_opts(host, _ip), do: [hostname: host]

  defp ip_literal?(host) do
    match?({:ok, _ip}, host |> to_charlist() |> :inet.parse_address())
  end

  defp host_header(%URI{host: host, port: port, scheme: scheme}) do
    if port == URI.default_port(scheme), do: host, else: "#{host}:#{port}"
  end

  # Returns `{:ok, absolute_url}` for a redirect to follow, `:none` when the response is
  # not a followable redirect, or `:error` when the `Location` cannot be resolved.
  defp redirect_target(response, base_url) do
    if status_code(response) in @redirect_statuses do
      case location_header(response) do
        nil ->
          :none

        location ->
          {:ok, base_url |> URI.merge(location) |> URI.to_string()}
      end
    else
      :none
    end
  rescue
    _ -> :error
  end

  defp status_code(%{status_code: code}), do: code
  defp status_code(_), do: nil

  defp location_header(%{headers: headers}) when is_list(headers) do
    Enum.find_value(headers, fn
      {name, value} -> if String.downcase(to_string(name)) == "location", do: value
      _ -> nil
    end)
  end

  defp location_header(_), do: nil

  # Defaults to `true` so a consumer without this configuration fails closed rather than
  # silently skipping validation.
  defp host_filtering_enabled? do
    (Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper) || [])
    |> Keyword.get(:host_filtering_enabled?, true)
  end
end
