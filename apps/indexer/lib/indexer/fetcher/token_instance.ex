defmodule Indexer.Fetcher.TokenInstance do
  require Logger

  alias Explorer.Chain
  alias Explorer.Token.InstanceMetadataRetriever

  def fetch_instance(token_contract_address_hash, token_id) do
    case InstanceMetadataRetriever.fetch_metadata(to_string(token_contract_address_hash), Decimal.to_integer(token_id)) do
      {:ok, %{metadata: metadata}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          metadata: metadata,
          error: nil
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

      {:ok, %{error: error}} ->
        upsert_token_instance_with_error(token_id, token_contract_address_hash, error)

      {:error, code, body} ->
        # Logger.debug(
        #   [
        #     "failed to fetch token instance metadata for #{inspect({to_string(token_contract_address_hash), Decimal.to_integer(token_id)})}: ",
        #     "http code: #{code}",
        #     inspect(result)
        #   ],
        #   fetcher: :token_instances
        # )
        upsert_token_instance_with_error(token_id, token_contract_address_hash, "request error: #{code}")

      {:error, reason} ->
        nil

        # result ->

        #   Logger.debug(
        #     [
        #       "failed to fetch token instance metadata for #{inspect({to_string(token_contract_address_hash), Decimal.to_integer(token_id)})}: ",
        #       inspect(result)
        #     ],
        #     fetcher: :token_instances
        #   )

        #   :ok
    end
  end

  defp upsert_token_instance_with_error(token_id, token_contract_address_hash, error) do
    params = %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      error: error
    }

    {:ok, _result} = Chain.upsert_token_instance(params)
  end
end
