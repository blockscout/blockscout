defmodule Explorer.SmartContract.Stylus.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """

  import Explorer.SmartContract.Helper,
    only: [
      fetch_data_for_stylus_verification: 1
    ]

  alias Explorer.SmartContract.StylusVerifierInterface

  require Logger

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

  defp evaluate_authenticity_inner(true, address_hash, params) do
    transaction_hash = fetch_data_for_stylus_verification(address_hash)
    rpc_endpoint = Application.get_env(:explorer, :json_rpc_named_arguments)[:transport_options][:url]

    params
    |> Map.take(["cargo_stylus_version", "repository_url", "commit", "path_prefix"])
    |> Map.put("rpc_endpoint", rpc_endpoint)
    |> Map.put("deployment_transaction", transaction_hash)
    |> StylusVerifierInterface.verify_github_repository()
  end

  defp evaluate_authenticity_inner(false, _address_hash, _params) do
    {:error, "Stylus verification is disabled"}
  end
end
