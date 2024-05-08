defmodule Explorer.MicroserviceInterfaces.Metadata do
  @moduledoc """
  Module to interact with Metadata microservice
  """

  alias Explorer.Chain.{Address.MetadataPreloader, Transaction}
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response

  import Explorer.Chain.Address.MetadataPreloader, only: [maybe_preload_meta: 3]

  require Logger
  @post_timeout :timer.seconds(5)

  @tags_per_address_limit 5
  @request_error_msg "Error while sending request to Metadata microservice"

  @spec get_addresses_tags([String.t()]) :: {:error, :disabled | <<_::416>> | Jason.DecodeError.t()} | {:ok, any()}
  def get_addresses_tags(addresses) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      body = %{
        addresses: Enum.join(addresses, ","),
        tagsLimit: @tags_per_address_limit,
        chainId: Application.get_env(:block_scout_web, :chain_id)
      }

      http_get_request(addresses_metadata_url(), body)
    end
  end

  defp http_get_request(url, params) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.get(url, headers, params: params, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
        body |> Jason.decode() |> decode_meta()

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

  defp addresses_metadata_url do
    "#{base_url()}/metadata"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
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
end
