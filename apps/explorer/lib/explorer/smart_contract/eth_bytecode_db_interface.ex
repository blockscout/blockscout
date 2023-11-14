defmodule Explorer.SmartContract.EthBytecodeDBInterface do
  @moduledoc """
    Adapter for interaction with https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db
  """

  def search_contract(%{"bytecode" => _, "bytecodeType" => _} = body, address_hash) do
    if chain_id = Application.get_env(:block_scout_web, :chain_id) do
      http_post_request(
        bytecode_search_all_sources_url(),
        Map.merge(body, %{
          "chain" => to_string(chain_id),
          "address" => to_string(address_hash)
        })
      )
    else
      http_post_request(bytecode_search_sources_url(), body)
    end
  end

  @doc """
    Function to search smart contracts in eth-bytecode-db, similar to `search_contract/2` but
      this function uses only `/api/v2/bytecodes/sources:search` method
  """
  @spec search_contract_in_eth_bytecode_internal_db(map()) :: {:error, any} | {:ok, any}
  def search_contract_in_eth_bytecode_internal_db(%{"bytecode" => _, "bytecodeType" => _} = body) do
    http_post_request(bytecode_search_sources_url(), body)
  end

  def process_verifier_response(%{"sourcifySources" => [src | _]}) do
    {:ok, Map.put(src, "sourcify?", true)}
  end

  def process_verifier_response(%{"ethBytecodeDbSources" => [src | _]}) do
    {:ok, src}
  end

  def process_verifier_response(%{"ethBytecodeDbSources" => [], "sourcifySources" => []}) do
    {:error, :no_matched_sources}
  end

  def process_verifier_response(%{"sources" => [src | _]}) do
    {:ok, src}
  end

  def process_verifier_response(%{"sources" => []}) do
    {:ok, nil}
  end

  def bytecode_search_sources_url do
    # workaround because of https://github.com/PSPDFKit-labs/bypass/issues/122
    if Mix.env() == :test do
      "#{base_api_url()}" <> "/bytecodes/sources_search"
    else
      "#{base_api_url()}" <> "/bytecodes/sources:search"
    end
  end

  def bytecode_search_all_sources_url do
    # workaround because of https://github.com/PSPDFKit-labs/bypass/issues/122
    if Mix.env() == :test do
      "#{base_api_url()}" <> "/bytecodes/sources_search_all"
    else
      "#{base_api_url()}" <> "/bytecodes/sources:search-all"
    end
  end

  use Explorer.SmartContract.RustVerifierInterfaceBehaviour
end
