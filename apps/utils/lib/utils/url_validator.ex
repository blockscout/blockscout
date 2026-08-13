# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.UrlValidator do
  @moduledoc """
  Validates outbound URLs built from attacker-controlled data (e.g. on-chain token
  metadata) against a blacklist of reserved/internal IP ranges, to prevent SSRF.

  Lives in `:utils` so it is reachable from every app that issues such requests
  (`:explorer`, `:nft_media_handler`). Configuration is read from the `:indexer`
  application environment, which is global and requires no compile-time dependency.
  """

  import Bitwise

  require Logger

  @reserved_ranges [
    # --- IPv4 ---
    # Current (local, "this") network
    "0.0.0.0/8",
    # Used for local communications within a private network
    "10.0.0.0/8",
    # [Shared address space](https://en.wikipedia.org/wiki/IPv4_shared_address_space) for communications between a service provider and its subscribers when using a carrier-grade NAT
    "100.64.0.0/10",
    # Used for [loopback addresses](https://en.wikipedia.org/wiki/Loopback_address) to the local host
    "127.0.0.0/8",
    # Used for [link-local addresses](https://en.wikipedia.org/wiki/Link-local_address) between two hosts on a single link when no IP address is otherwise specified, such as would have normally been retrieved from a DHCP server
    "169.254.0.0/16",
    # Used for local communications within a private network
    "172.16.0.0/12",
    # IETF Protocol Assignments, [DS-Lite](https://en.wikipedia.org/wiki/DS-Lite)
    "192.0.0.0/29",
    # Assigned as TEST-NET-1, documentation and examples
    "192.0.2.0/24",
    # Reserved. Formerly used for IPv6 to IPv4 relay (included IPv6 address block)
    "192.88.99.0/24",
    # Used for local communications within a private network
    "192.168.0.0/16",
    # Used for benchmark testing of inter-network communications between two separate subnets
    "198.18.0.0/15",
    # Assigned as TEST-NET-2, documentation and examples
    "198.51.100.0/24",
    # Assigned as TEST-NET-3, documentation and examples
    "203.0.113.0/24",
    # In use for [multicast](https://en.wikipedia.org/wiki/IP_multicast) (former Class D network)
    "224.0.0.0/4",
    # Reserved for future use (former Class E network)
    "240.0.0.0/4",
    # Reserved for the "limited [broadcast](https://en.wikipedia.org/wiki/Broadcast_address)" destination address
    "255.255.255.255/32",
    # --- IPv6 ---
    # Unspecified address
    "::/128",
    # Loopback
    "::1/128",
    # Discard-only address block
    "100::/64",
    # NAT64 well-known prefix
    "64:ff9b::/96",
    # 6to4
    "2002::/16",
    # Teredo tunneling (embeds an IPv4 address)
    "2001::/32",
    # Documentation and examples
    "2001:db8::/32",
    # Unique local addresses (covers fc00::/8 and fd00::/8)
    "fc00::/7",
    # Link-local addresses
    "fe80::/10",
    # Multicast
    "ff00::/8"
  ]

  @doc """
  Validates the given URI.

  ## Parameters
  - uri: The URI to be validated.

  ## Returns
  - :ok if the URI is valid.
  - {:error, reason} if the URI is invalid.

  ## Examples

      iex> validate_uri("https://example.com")
      :ok

      iex> validate_uri("invalid_uri")
      {:error, :empty_host}

      iex> validate_uri("https://not_existing_domain.com")
      {:error, :nxdomain}
  """
  @spec validate_uri(String.t()) :: :ok | {:error, atom()}
  def validate_uri(uri) do
    with {:not_printable, false} <- {:not_printable, not String.printable?(uri)},
         {:empty_host, %URI{host: host, scheme: scheme}} when host not in ["", nil] <- {:empty_host, URI.parse(uri)},
         {:disallowed_protocol, false} <- {:disallowed_protocol, scheme not in allowed_uri_protocols()},
         {:nxdomain, ip_list} when not is_nil(ip_list) <- {:nxdomain, host_to_ip_list(host)},
         {:blacklist, false} <- {:blacklist, not Enum.all?(ip_list, &allowed_ip?/1)} do
      :ok
    else
      {reason, _} ->
        {:error, reason}
    end
  end

  @spec host_to_ip_list(String.t()) :: [tuple()] | nil
  defp host_to_ip_list(host) do
    host
    |> to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, ip} ->
        [ip]

      {:error, _reason} ->
        case resolve(host, :a) ++ resolve(host, :aaaa) do
          [] -> nil
          ip_list -> ip_list
        end
    end
  end

  @spec resolve(String.t(), :a | :aaaa) :: [tuple()]
  defp resolve(host, type) do
    case DNS.resolve(host, type) do
      {:ok, ip_list} when is_list(ip_list) -> ip_list
      _ -> []
    end
  end

  @spec allowed_ip?(tuple()) :: boolean()
  defp allowed_ip?(ip) do
    normalized = normalize_mapped_ipv4(ip)

    not Enum.any?(prepare_cidr_blacklist(), fn range ->
      InetCidr.contains?(range, normalized)
    end)
  end

  # Normalizes an IPv4-mapped IPv6 address (::ffff:a.b.c.d) to its IPv4 tuple so it is
  # matched against the IPv4 reserved ranges (e.g. ::ffff:127.0.0.1 -> 127.0.0.0/8).
  @spec normalize_mapped_ipv4(tuple()) :: tuple()
  defp normalize_mapped_ipv4({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    {ab >>> 8, ab &&& 0xFF, cd >>> 8, cd &&& 0xFF}
  end

  defp normalize_mapped_ipv4(ip), do: ip

  defp prepare_cidr_blacklist do
    from_cache = :persistent_term.get(:parsed_cidr_list, nil)

    from_cache ||
      (
        cidr_list =
          (config(:cidr_blacklist, []) ++ @reserved_ranges)
          |> Enum.flat_map(fn cidr ->
            case InetCidr.parse_cidr(cidr) do
              {:ok, cidr} ->
                [cidr]

              _ ->
                Logger.warning("Invalid CIDR range: #{inspect(cidr)}")
                []
            end
          end)

        :persistent_term.put(:parsed_cidr_list, cidr_list)
        cidr_list
      )
  end

  defp allowed_uri_protocols do
    config(:allowed_uri_protocols, ["http", "https"])
  end

  # Defaults are applied here so a consumer without this configuration still validates
  # (fails closed) instead of crashing on a missing key.
  defp config(key, default) do
    (Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper) || [])
    |> Keyword.get(key, default)
  end
end
