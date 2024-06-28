defmodule Indexer.Fetcher.Celo.EpochBlockOperations.CoreContractVersion do
  import Indexer.Fetcher.Celo.Helper, only: [abi_to_method_id: 1]
  import Indexer.Helper, only: [read_contracts_with_retries: 5]

  @repeated_request_max_retries 3

  @get_version_number_abi [
    %{
      "name" => "getVersionNumber",
      "type" => "function",
      "payable" => false,
      "constant" => true,
      "stateMutability" => "pure",
      "inputs" => [],
      "outputs" => [
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"},
        %{"type" => "uint256"}
      ]
    }
  ]

  @get_version_number_method_id @get_version_number_abi |> abi_to_method_id()

  def fetch(contract_address, block_number, json_rpc_named_arguments) do
    request = %{
      contract_address: contract_address,
      method_id: @get_version_number_method_id,
      args: [],
      block_number: block_number
    }

    read_contracts_with_retries(
      [request],
      @get_version_number_abi,
      json_rpc_named_arguments,
      @repeated_request_max_retries,
      false
    )
    |> elem(0)
    |> case do
      [ok: [storage, major, minor, patch]] ->
        {:ok, {storage, major, minor, patch}}

      # Celo Core Contracts deployed to a live network without the
      # `getVersionNumber()` function, such as the original set of core
      # contracts, are to be considered version 1.1.0.0.
      #
      # https://docs.celo.org/community/release-process/smart-contracts#core-contracts
      [error: "(-32000) execution reverted"] ->
        {:ok, {1, 1, 0, 0}}

      errors ->
        {:error, errors}
    end
  end
end
