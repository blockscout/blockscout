defmodule Explorer.SmartContract.Stylus.Verifier do
  @moduledoc """
    Verifies Stylus smart contracts by comparing their source code against deployed bytecode.

    This module handles verification of Stylus smart contracts through their GitHub repository
    source code. It interfaces with a verification microservice that:
    - Fetches source code from the specified GitHub repository and commit
    - Compiles the code using the specified cargo-stylus version
    - Compares the resulting bytecode against the deployed contract bytecode
    - Returns verification details including ABI and contract metadata
  """
  alias EthereumJSONRPC.Utility.CommonHelper
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.SmartContract.StylusVerifierInterface

  require Logger

  @doc """
    Verifies a Stylus smart contract by comparing source code from a GitHub repository against the deployed bytecode using a verification microservice.

    ## Parameters
    - `address_hash`: Contract address
    - `params`: Map containing verification parameters:
      - `cargo_stylus_version`: Version of cargo-stylus used for deployment
      - `repository_url`: GitHub repository URL containing contract code
      - `commit`: Git commit hash used for deployment
      - `path_prefix`: Optional path prefix if contract is not in repository root

    ## Returns
    - `{:ok, map}` with verification details:
      - `abi`: Contract ABI (optional)
      - `contract_name`: Contract name (optional)
      - `package_name`: Package name
      - `files`: Map of file paths to contents used in verification
      - `cargo_stylus_version`: Version of cargo-stylus used
      - `github_repository_metadata`: Repository metadata (optional)
    - `{:error, any}` if verification fails or is disabled
  """
  @spec evaluate_authenticity(EthereumJSONRPC.address() | Hash.Address.t(), map()) ::
          {:ok, map()} | {:error, any()}
  def evaluate_authenticity(address_hash, params) do
    evaluate_authenticity_inner(StylusVerifierInterface.enabled?(), address_hash, params)
  rescue
    exception ->
      Logger.error(fn ->
        [
          "Error while verifying smart-contract address: #{address_hash}, params: #{inspect(params, limit: :infinity, printable_limit: :infinity)}: ",
          Exception.format(:error, exception, __STACKTRACE__)
        ]
      end)
  end

  # Verifies the authenticity of a Stylus smart contract using GitHub repository source code.
  #
  # This function retrieves the contract creation transaction and blockchain RPC endpoint,
  # which together with passed parameters are required by the verification microservice to
  # validate the contract deployment and verify the source code against the deployed
  # bytecode.
  #
  # ## Parameters
  # - `true`: Required boolean flag to proceed with verification
  # - `address_hash`: Contract address
  # - `params`: Map containing verification parameters
  #
  # ## Returns
  # - `{:ok, map}` with verification details including ABI, contract name, and source files
  # - `{:error, any}` if verification fails
  @spec evaluate_authenticity_inner(boolean(), EthereumJSONRPC.address() | Hash.Address.t(), map()) ::
          {:ok, map()} | {:error, any()}
  defp evaluate_authenticity_inner(true, address_hash, params) do
    transaction_hash = fetch_data_for_stylus_verification(address_hash)
    rpc_endpoint = CommonHelper.get_available_url()

    params
    |> Map.take(["cargo_stylus_version", "repository_url", "commit", "path_prefix"])
    |> Map.put("rpc_endpoint", rpc_endpoint)
    |> Map.put("deployment_transaction", transaction_hash)
    |> StylusVerifierInterface.verify_github_repository()
  end

  defp evaluate_authenticity_inner(false, _address_hash, _params) do
    {:error, "Stylus verification is disabled"}
  end

  # Retrieves the transaction hash that created a Stylus smart contract.

  # Looks up the creation transaction for the given contract address and returns its hash.
  # Checks both regular transactions and internal transactions.

  # ## Parameters
  # - `address_hash`: The address hash of the smart contract as a binary or `t:Hash.Address.t/0`

  # ## Returns
  # - `t:Hash.t/0` - The transaction hash if found
  # - `nil` - If no creation transaction exists
  @spec fetch_data_for_stylus_verification(binary() | Hash.Address.t()) :: Hash.t() | nil
  defp fetch_data_for_stylus_verification(address_hash) do
    case SmartContract.creation_transaction_with_bytecode(address_hash) do
      %{transaction: transaction} ->
        transaction.hash

      %{internal_transaction: internal_transaction} ->
        internal_transaction.transaction_hash

      _ ->
        nil
    end
  end
end
