defmodule Explorer.MetadataURIValidator do
  @moduledoc """
  Validates metadata URI
  """

  require Logger

  @reserved_ranges [
    "0.0.0.0/8",
    "10.0.0.0/8",
    "100.64.0.0/10",
    "127.0.0.0/8",
    "169.254.0.0/16",
    "172.16.0.0/12",
    "192.0.0.0/29",
    "192.0.2.0/24",
    "192.88.99.0/24",
    "192.168.0.0/16",
    "198.18.0.0/15",
    "198.51.100.0/24",
    "203.0.113.0/24",
    "224.0.0.0/4",
    "240.0.0.0/4",
    "255.255.255.255/32"
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
    with {:empty_host, %URI{host: host, scheme: scheme}} when host not in ["", nil] <- {:empty_host, URI.parse(uri)},
         {:disallowed_protocol, true} <- {:disallowed_protocol, scheme in allowed_uri_protocols()},
         {:nxdomain, ip_list} when not is_nil(ip_list) <- {:nxdomain, host_to_ip_list(host)},
         {:blacklist, true} <- {:blacklist, Enum.all?(ip_list, &allowed_ip?/1)} do
      :ok
    else
      {reason, _} ->
        {:error, reason}
    end
  end

  defp host_to_ip_list(host) do
    host
    |> to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, ip} ->
        [ip]

      {:error, :einval} ->
        case DNS.resolve(host) do
          {:ok, ip_list} -> ip_list
          {:error, _reason} -> nil
        end
    end
  end

  defp allowed_ip?(ip) do
    not Enum.any?(prepare_cidr_blacklist(), fn range ->
      range
      |> InetCidr.parse_cidr!()
      |> InetCidr.contains?(ip)
    end)
  end

  defp prepare_cidr_blacklist do
    case :persistent_term.get(:parsed_cidr_list, nil) do
      nil ->
        cidr_list =
          (Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)[:cidr_blacklist] ++ @reserved_ranges)
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

      cidr_list ->
        cidr_list
    end
  end

  defp allowed_uri_protocols do
    Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)[:allowed_uri_protocols]
  end
end
