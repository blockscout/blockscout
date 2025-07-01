defmodule Explorer.MicroserviceInterfaces.BENS do
  @moduledoc """
    Interface to interact with Blockscout ENS microservice
  """

  alias Explorer.{Chain, HttpClient}
  alias Explorer.Chain.Address.MetadataPreloader

  alias Explorer.Chain.{Address, Transaction}

  alias Explorer.Utility.Microservice

  require Logger

  import Explorer.Chain.Address.MetadataPreloader, only: [maybe_preload_meta: 3]

  @post_timeout :timer.seconds(5)
  @request_error_msg "Error while sending request to BENS microservice"

  @doc """
    Batch request for ENS names via POST {{baseUrl}}/api/v1/:chainId/addresses:batch-resolve-names
  """
  @spec ens_names_batch_request([binary()]) :: {:error, :disabled | binary() | Jason.DecodeError.t()} | {:ok, any}
  def ens_names_batch_request(addresses) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      body = %{
        addresses: Enum.map(addresses, &to_string/1)
      }

      http_post_request(batch_resolve_name_url(), body)
    end
  end

  @doc """
    Request for ENS name via GET {{baseUrl}}/api/v1/:chainId/addresses:lookup
  """
  @spec address_lookup(binary()) :: {:error, :disabled | binary() | Jason.DecodeError.t()} | {:ok, any}
  def address_lookup(address) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{
        "address" => to_string(address),
        "resolved_to" => true,
        "owned_by" => false,
        "only_active" => true,
        "order" => "ASC"
      }

      http_get_request(address_lookup_url(), query_params)
    end
  end

  @doc """
    Request for ENS name via GET {{baseUrl}}/api/v1/:chainId/addresses/{address_hash}
  """
  @spec get_address(binary()) :: map() | nil
  def get_address(address) do
    result =
      with :ok <- Microservice.check_enabled(__MODULE__) do
        http_get_request(get_address_url(address), nil)
      end

    parse_get_address_response(result)
  end

  @doc """
    Lookup for ENS domain name via GET {{baseUrl}}/api/v1/:chainId/domains:lookup
  """
  @spec ens_domain_lookup(binary()) :: {:error, :disabled | binary() | Jason.DecodeError.t()} | {:ok, any}
  def ens_domain_lookup(domain) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      query_params = %{
        "name" => domain,
        "only_active" => true,
        "sort" => "registration_date",
        "order" => "DESC"
      }

      http_get_request(domain_lookup_url(), query_params)
    end
  end

  @doc """
    Request for ENS name via GET {{baseUrl}}/api/v1/:chainId/domains:lookup
  """
  @spec ens_domain_name_lookup(binary()) ::
          nil | %{address_hash: binary(), expiry_date: any(), name: any(), names_count: integer(), protocol: any()}
  def ens_domain_name_lookup(domain) do
    domain |> ens_domain_lookup() |> parse_lookup_response()
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HttpClient.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %{body: body, status_code: 200}} ->
        Jason.decode(body)

      {_, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to BENS microservice url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  defp http_get_request(url, query_params) do
    case HttpClient.get(url, [], params: query_params) do
      {:ok, %{body: body, status_code: 200}} ->
        Jason.decode(body)

      {_, error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to BENS microservice url: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  @spec enabled?() :: boolean()
  def enabled?, do: Microservice.check_enabled(__MODULE__) == :ok

  defp batch_resolve_name_url do
    # workaround for https://github.com/PSPDFKit-labs/bypass/issues/122
    if Mix.env() == :test do
      "#{addresses_url()}:batch_resolve_names"
    else
      "#{addresses_url()}:batch-resolve-names"
    end
  end

  defp address_lookup_url do
    "#{addresses_url()}:lookup"
  end

  defp get_address_url(address) do
    "#{addresses_url()}/#{address}"
  end

  defp domain_lookup_url do
    "#{domains_url()}%3Alookup"
  end

  defp addresses_url do
    "#{base_url()}/addresses"
  end

  defp domains_url do
    "#{base_url()}/domains"
  end

  defp base_url do
    chain_id = Application.get_env(:block_scout_web, :chain_id)
    "#{Microservice.base_url(__MODULE__)}/api/v1/#{chain_id}"
  end

  defp parse_lookup_response(
         {:ok,
          %{
            "items" =>
              [
                %{
                  "name" => name,
                  "expiry_date" => expiry_date,
                  "resolved_address" => %{"hash" => address_hash_string},
                  "protocol" => protocol
                }
                | _other
              ] = items
          }}
       ) do
    {:ok, hash} = Chain.string_to_address_hash(address_hash_string)

    %{
      name: name,
      expiry_date: expiry_date,
      names_count: Enum.count(items),
      address_hash: Address.checksum(hash),
      protocol: protocol
    }
  end

  defp parse_lookup_response(_), do: nil

  defp parse_get_address_response(
         {:ok,
          %{
            "domain" => %{
              "name" => name,
              "expiry_date" => expiry_date,
              "resolved_address" => %{"hash" => address_hash_string}
            },
            "resolved_domains_count" => resolved_domains_count
          }}
       ) do
    {:ok, hash} = Chain.string_to_address_hash(address_hash_string)

    %{
      name: name,
      expiry_date: expiry_date,
      names_count: resolved_domains_count,
      address_hash: Address.checksum(hash)
    }
  end

  defp parse_get_address_response(_), do: nil

  @doc """
  Preloads ENS data to the list if BENS is enabled
  """
  @spec maybe_preload_ens(MetadataPreloader.supported_input()) :: MetadataPreloader.supported_input()
  def maybe_preload_ens(argument) do
    maybe_preload_meta(argument, __MODULE__, &MetadataPreloader.preload_ens_to_list/1)
  end

  @doc """
  Preloads ENS data to the list of the search results if BENS is enabled
  """
  @spec maybe_preload_ens_info_to_search_results(list()) :: list()
  def maybe_preload_ens_info_to_search_results(list) do
    maybe_preload_meta(list, __MODULE__, &MetadataPreloader.preload_ens_info_to_search_results/1)
  end

  @doc """
  Preloads ENS data to the transaction results if BENS is enabled
  """
  @spec maybe_preload_ens_to_transaction(Transaction.t()) :: Transaction.t()
  def maybe_preload_ens_to_transaction(transaction) do
    maybe_preload_meta(transaction, __MODULE__, &MetadataPreloader.preload_ens_to_transaction/1)
  end

  @doc """
  Preloads ENS data to the address results if BENS is enabled
  """
  @spec maybe_preload_ens_to_address(Address.t()) :: Address.t()
  def maybe_preload_ens_to_address(address) do
    maybe_preload_meta(address, __MODULE__, &MetadataPreloader.preload_ens_to_address/1)
  end
end
