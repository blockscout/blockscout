defmodule Explorer.MicroserviceInterfaces.MultichainSearch do
  @moduledoc """
  Module to interact with Multichain search microservice
  """

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Cache.NetVersion
  alias Explorer.Chain.Hash
  alias Explorer.Utility.Microservice
  alias HTTPoison.Response

  require Logger

  @post_timeout :timer.minutes(5)
  @request_error_msg "Error while sending request to Multichain Search Service"

  @spec batch_import(%{
          addresses: list(),
          blocks: list(),
          transactions: list()
        }) :: {:error, :disabled | <<_::416>> | Jason.DecodeError.t()} | {:ok, any()}
  def batch_import(params) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      body = format_batch_import_params(params)

      http_post_request(batch_import_url(), body)
    end
  end

  defp http_post_request(url, body) do
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers, recv_timeout: @post_timeout) do
      {:ok, %Response{body: body, status_code: 200}} ->
        body |> Jason.decode()

      error ->
        old_truncate = Application.get_env(:logger, :truncate)
        Logger.configure(truncate: :infinity)

        Logger.error(fn ->
          [
            "Error while sending request to microservice url: #{url}, body: #{inspect(body, limit: :infinity, printable_limit: :infinity)}: ",
            inspect(error, limit: :infinity, printable_limit: :infinity)
          ]
        end)

        Logger.configure(truncate: old_truncate)
        {:error, @request_error_msg}
    end
  end

  defp format_batch_import_params(%{
         addresses: addresses,
         blocks: blocks,
         transactions: transactions
       }) do
    chain_id = NetVersion.get_version()
    block_ranges = get_block_ranges(blocks)

    address_hashes =
      addresses
      |> Enum.map(fn address ->
        %{
          hash: Hash.to_string(address.hash),
          is_contract: !is_nil(address.contract_code),
          is_verified_contract: address.verified,
          is_token: token?(address.token),
          ens_name: address.ens_domain_name,
          token_name: get_token_name(address.token),
          token_type: get_token_type(address.token),
          contract_name: get_smart_contract_name(address.smart_contract)
        }
      end)

    block_hashes =
      blocks
      |> Enum.map(
        &%{
          hash: Hash.to_string(&1.hash),
          hash_type: "BLOCK"
        }
      )

    transaction_hashes =
      transactions
      |> Enum.map(
        &%{
          hash: Hash.to_string(&1.hash),
          hash_type: "TRANSACTION"
        }
      )

    block_transaction_hashes = block_hashes ++ transaction_hashes

    %{
      api_key: api_key(),
      chain_id: to_string(chain_id),
      addresses: address_hashes,
      block_ranges: block_ranges,
      hashes: block_transaction_hashes
    }
  end

  def token?(nil), do: false

  def token?(%NotLoaded{}), do: false

  def token?(_), do: true

  defp get_token_name(nil), do: nil

  defp get_token_name(%NotLoaded{}), do: nil

  defp get_token_name(token), do: token.name

  defp get_smart_contract_name(nil), do: nil

  defp get_smart_contract_name(%NotLoaded{}), do: nil

  defp get_smart_contract_name(token), do: token.name

  defp get_token_type(nil), do: "UNSPECIFIED"

  defp get_token_type(%NotLoaded{}), do: "UNSPECIFIED"

  defp get_token_type(token), do: token.type

  defp get_block_ranges([]), do: []

  defp get_block_ranges(blocks) do
    {min_block_number, max_block_number} =
      blocks
      |> Enum.map(& &1.number)
      |> Enum.min_max()

    [
      %{
        min_block_number: to_string(min_block_number),
        max_block_number: to_string(max_block_number)
      }
    ]
  end

  defp batch_import_url do
    "#{base_url()}/import:batch"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end

  defp api_key do
    Microservice.api_key(__MODULE__)
  end
end
