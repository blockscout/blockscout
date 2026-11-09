# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.SmartContract.EthBytecodeDBInterface do
  @moduledoc """
    Adapter for interaction with https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db
  """

  def search_contract(%{"bytecode" => _, "bytecodeType" => _} = body, address_hash, metadata) do
    if chain_id = Application.get_env(:block_scout_web, :chain_id) do
      http_post_request(
        bytecode_search_all_sources_url(),
        body
        |> Map.merge(%{
          "chain" => to_string(chain_id),
          "address" => to_string(address_hash)
        })
        |> append_metadata(metadata)
      )
    else
      http_post_request(bytecode_search_sources_url(), append_metadata(body, metadata))
    end
  end

  @doc """
    Function to search smart contracts in eth-bytecode-db, similar to `search_contract/2` but
      this function uses only `/api/v2/bytecodes/sources:search` method
  """
  @spec search_contract_in_eth_bytecode_internal_db(map(), binary(), keyword(), map()) :: {:error, any} | {:ok, any}
  def search_contract_in_eth_bytecode_internal_db(
        %{"bytecode" => _, "bytecodeType" => _} = body,
        address_hash_string,
        options,
        metadata
      ) do
    chain_id = Application.get_env(:block_scout_web, :chain_id)

    {url, body} =
      cond do
        Keyword.get(options, :only_verifier_alliance?, false) ->
          {bytecode_search_alliance_sources_url(),
           %{
             "chain" => to_string(chain_id),
             "address" => address_hash_string
           }}

        Keyword.get(options, :only_eth_bytecode_db?, false) ->
          {bytecode_search_sources_url(), body}

        true ->
          {bytecode_search_all_sources_url(),
           Map.merge(body, %{
             "chain" => to_string(chain_id),
             "address" => address_hash_string,
             "onlyLocal" => true
           })}
      end

    http_post_request(url, body |> append_metadata(metadata), options)
  end

  # Source lists returned by `sources:search-all`, in order of preference among
  # candidates with the same match type. The second element is the flag set on
  # the chosen source so that the publisher records where it came from.
  @search_all_source_lists [
    {"allianceSources", "verifier_alliance?"},
    {"sourcifySources", "sourcify?"},
    {"ethBytecodeDbSources", nil}
  ]

  @doc """
    Picks the source to verify the contract with from a `sources:search-all`
    response.

    A `FULL` match from any of the lists is always preferred over a `PARTIAL`
    one. Among candidates with the same match type, verifier alliance sources
    win over Sourcify ones, which in turn win over eth-bytecode-db ones. Every
    element of every list is considered, not only the head, since
    eth-bytecode-db orders its list by update time rather than by match type.

    For responses of the other search endpoints (`sources:search`,
    `sources:search-alliance`) the first returned source is taken.
  """
  @spec process_verifier_response(map(), keyword()) :: {:ok, map() | nil} | {:error, :no_matched_sources}
  def process_verifier_response(response, options)

  def process_verifier_response(response, _options)
      when is_map_key(response, "ethBytecodeDbSources") or is_map_key(response, "sourcifySources") or
             is_map_key(response, "allianceSources") do
    candidates =
      Enum.flat_map(@search_all_source_lists, fn {key, flag} ->
        response
        |> Map.get(key, [])
        |> Enum.map(&tag_source(&1, flag))
      end)

    case Enum.find(candidates, &full_match?/1) || List.first(candidates) do
      nil -> {:error, :no_matched_sources}
      source -> {:ok, source}
    end
  end

  def process_verifier_response(%{"sources" => [src | _]}, options) do
    if Keyword.get(options, :only_verifier_alliance?, false) do
      {:ok, Map.put(src, "verifier_alliance?", true)}
    else
      {:ok, src}
    end
  end

  def process_verifier_response(%{"sources" => []}, _) do
    {:ok, nil}
  end

  defp tag_source(source, nil), do: source
  defp tag_source(source, flag), do: Map.put(source, flag, true)

  defp full_match?(%{"matchType" => "FULL"}), do: true
  defp full_match?(_), do: false

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

  def bytecode_search_alliance_sources_url do
    # workaround because of https://github.com/PSPDFKit-labs/bypass/issues/122
    if Mix.env() == :test do
      "#{base_api_url()}" <> "/bytecodes/sources_search_alliance"
    else
      "#{base_api_url()}" <> "/bytecodes/sources:search-alliance"
    end
  end

  use Explorer.SmartContract.RustVerifierInterfaceBehaviour
end
