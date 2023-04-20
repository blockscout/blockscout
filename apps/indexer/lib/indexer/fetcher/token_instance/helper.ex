defmodule Indexer.Fetcher.TokenInstance.Helper do
  @moduledoc """
    Common functions for Indexer.Fetcher.TokenInstance fetchers
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Hash, Token.Instance}
  alias Explorer.Token.InstanceMetadataRetriever

  @spec fetch_instance(Hash.Address.t(), Decimal.t() | non_neg_integer(), boolean()) :: {:ok, Instance.t()} | :ignore
  def fetch_instance(token_contract_address_hash, token_id, is_retry?) do
    token_id = prepare_token_id(token_id)

    case InstanceMetadataRetriever.fetch_metadata(to_string(token_contract_address_hash), token_id) do
      {:ok, %{metadata: metadata}} ->
        params = %{
          token_id: token_id,
          token_contract_address_hash: token_contract_address_hash,
          metadata: metadata,
          error: nil
        }

        {:ok, _result} = Chain.upsert_token_instance(params)

      {:ok, %{error: error}} ->
        upsert_token_instance_with_error(token_id, token_contract_address_hash, error, is_retry?)

      {:error_code, code} ->
        upsert_token_instance_with_error(token_id, token_contract_address_hash, "request error: #{code}", is_retry?)

      {:error, reason} ->
        upsert_token_instance_with_error(token_id, token_contract_address_hash, reason, is_retry?)
    end
  end

  defp prepare_token_id(%Decimal{} = token_id), do: Decimal.to_integer(token_id)
  defp prepare_token_id(token_id), do: token_id

  defp upsert_token_instance_with_error(_token_id, _token_contract_address_hash, _error, true), do: :ignore

  defp upsert_token_instance_with_error(token_id, token_contract_address_hash, error, _is_retry?) do
    params = %{
      token_id: token_id,
      token_contract_address_hash: token_contract_address_hash,
      error: error
    }

    {:ok, _result} = Chain.upsert_token_instance(params)
  end
end
