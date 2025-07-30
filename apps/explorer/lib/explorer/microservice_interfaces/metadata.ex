defmodule Explorer.MicroserviceInterfaces.Metadata do
  @moduledoc """
  Module to interact with Metadata microservice
  """

  alias Explorer.{Chain, HttpClient}
  alias Explorer.Chain.{Address.MetadataPreloader, Transaction}
  alias Explorer.Utility.Microservice

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.Chain.Address.MetadataPreloader, only: [maybe_preload_meta: 3]
  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [proxy_implementations_association: 0]

  require Logger
  @request_timeout :timer.seconds(5)

  @tags_per_address_limit 5
  @page_size 50
  @request_error_msg "Error while sending request to Metadata microservice"
  @service_disabled "Service is disabled"

  @doc """
  Retrieves tags for a list of addresses.

  ## Parameters
  - `addresses`: A list of addresses for which tags need to be fetched.

  ## Returns
    - A map with metadata tags from microservice. Returns `:ignore` when the input list is empty.

  ## Examples

      iex> get_addresses_tags([])
      :ignore

  """
  @spec get_addresses_tags([String.t()]) ::
          {:error, :disabled | <<_::416>> | Jason.DecodeError.t()} | {:ok, any()} | :ignore
  def get_addresses_tags([]), do: :ignore

  def get_addresses_tags(addresses) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      params = %{
        addresses: Enum.join(addresses, ","),
        tags_limit: @tags_per_address_limit,
        chain_id: Application.get_env(:block_scout_web, :chain_id)
      }

      http_get_request(addresses_metadata_url(), params)
    end
  end

  @doc """
    Get addresses list from Metadata microservice. Then preloads addresses from local DB.
  """
  @spec get_addresses(map()) :: {:error | integer(), any()}
  def get_addresses(params) do
    case Microservice.check_enabled(__MODULE__) do
      :ok ->
        params =
          params
          |> Map.put("page_size", @page_size)
          |> Map.put("chain_id", Application.get_env(:block_scout_web, :chain_id))

        http_get_request_for_proxy_method(addresses_url(), params, &prepare_addresses_response/1)

      _ ->
        {501, %{error: @service_disabled}}
    end
  end

  @doc """
  Searches for metadata tags by name, handling pagination via `next_page_params`.

  ## Parameters
    - `name`: The name of the tag to search for.
    - `next_page_params`: A map containing pagination parameters from the previous request.

  ## Returns
    - `{:ok, %{items: list(), next_page_params: map() | nil}}` on success.
    - `{:error, String.t()}` on error.
    - `:disabled` if the microservice is disabled.
  """
  @spec search_tags_by_name(String.t(), map() | nil) :: {:ok, map()} | :disabled | {:error, String.t()}
  def search_tags_by_name(name, next_page_params) do
    case Microservice.check_enabled(__MODULE__) do
      :ok ->
        params =
          Map.merge(next_page_params || %{}, %{
            name: name,
            chain_id: Application.get_env(:block_scout_web, :chain_id),
            tag_types: "protocol,name"
          })

        http_get_request(tags_search_url(), params, &prepare_search_results/1)

      _ ->
        :disabled
    end
  end

  defp http_get_request(url, params, parsing_function \\ &decode_meta/1) do
    headers = []

    case HttpClient.get(url, headers, params: params, recv_timeout: @request_timeout) do
      {:ok, %{body: body, status_code: 200}} ->
        body |> Jason.decode() |> parsing_function.()

      {_, error} ->
        Logger.error(fn ->
          [
            "Error while sending request to Metadata microservice url: #{url}, params: #{inspect(params)}: ",
            inspect(error)
          ]
        end)

        {:error, @request_error_msg}
    end
  end

  defp http_get_request_for_proxy_method(url, params, parsing_function) do
    case HttpClient.get(url, [], params: params, recv_timeout: config()[:proxy_requests_timeout]) do
      {:ok, %{body: body, status_code: 200}} ->
        {200, body |> Jason.decode() |> parsing_function.()}

      {_, %{body: body, status_code: status_code} = error} ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to Metadata microservice url: #{url}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:ok, response_json} = Jason.decode(body)
        {status_code, response_json}

      {:error, reason} ->
        {500, %{error: reason}}
    end
  end

  defp addresses_metadata_url do
    "#{base_url()}/metadata"
  end

  defp addresses_url do
    "#{base_url()}/addresses"
  end

  defp tags_search_url do
    "#{base_url()}/tags%3Asearch"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end

  defp config do
    Application.get_env(:explorer, __MODULE__)
  end

  @spec enabled?() :: boolean()
  def enabled?, do: Microservice.check_enabled(__MODULE__) == :ok

  @doc """
  Preloads metadata to supported entities if Metadata microservice is enabled
  """
  @spec maybe_preload_metadata(MetadataPreloader.supported_input()) :: MetadataPreloader.supported_input()
  def maybe_preload_metadata(argument) do
    maybe_preload_meta(argument, __MODULE__, &MetadataPreloader.preload_metadata_to_list/1)
  end

  @doc """
  Preloads metadata to transaction if Metadata microservice is enabled
  """
  @spec maybe_preload_metadata_to_transaction(Transaction.t()) :: Transaction.t()
  def maybe_preload_metadata_to_transaction(transaction) do
    maybe_preload_meta(transaction, __MODULE__, &MetadataPreloader.preload_metadata_to_transaction/1)
  end

  defp decode_meta({:ok, %{"addresses" => addresses} = result}) do
    prepared_address =
      Enum.reduce(addresses, %{}, fn {address, meta}, acc ->
        prepared_meta = Map.put(meta, "tags", meta["tags"] |> Enum.map(&decode_meta_in_tag/1))
        Map.put(acc, address, prepared_meta)
      end)

    {:ok, Map.put(result, "addresses", prepared_address)}
  end

  defp decode_meta(other), do: other

  defp decode_meta_in_tag(%{"meta" => meta} = tag) do
    Map.put(tag, "meta", Jason.decode!(meta))
  end

  defp prepare_addresses_response({:ok, %{"items" => addresses} = response}) do
    {:ok,
     Map.put(
       response,
       "items",
       addresses
       |> Chain.hashes_to_addresses(
         necessity_by_association: %{
           :names => :optional,
           :smart_contract => :optional,
           proxy_implementations_association() => :optional
         }
       )
       |> maybe_preload_ens()
       |> maybe_preload_metadata()
     )}
  end

  defp prepare_addresses_response(_), do: :error

  defp prepare_search_results({:ok, %{"items" => items, "next_page_params" => next_page_params}}) do
    items =
      Enum.reduce(items, [], fn %{"tag" => tag, "addresses" => addresses}, tags_list ->
        prepared_tag = decode_meta_in_tag(tag)

        tags_list ++
          (addresses
           |> Enum.with_index(fn address, index ->
             address_hash = Chain.string_to_address_hash_or_nil(address)
             address_hash && %{metadata: prepared_tag, hash: address_hash, addresses_index: index}
           end)
           |> Enum.reject(&is_nil/1))
      end)

    {:ok, %{items: items, next_page_params: next_page_params}}
  end

  defp prepare_search_results(_), do: :error
end
