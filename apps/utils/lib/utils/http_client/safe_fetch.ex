# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.HttpClient.SafeFetch do
  @moduledoc """
  Performs an HTTP request against an attacker-controlled URL while validating the
  host (and every redirect target) against `Utils.UrlValidator`.

  Neither `Tesla.Middleware.FollowRedirects` nor hackney exposes a per-redirect hook,
  so redirects are followed manually here: the request is issued with automatic
  redirect-following disabled, and each `Location` is re-validated before the next hop.

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
    following.

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
    with :ok <- maybe_validate(url, validate_host?),
         {:ok, response} <- transport.(url, headers, Keyword.get(opts, :transport_opts, [])) do
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

  defp maybe_validate(url, true) do
    if host_filtering_enabled?() do
      UrlValidator.validate_uri(url)
    else
      :ok
    end
  end

  defp maybe_validate(_url, false), do: :ok

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
