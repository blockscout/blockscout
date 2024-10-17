# credo:disable-for-this-file
defmodule Explorer.SmartContract.Vyper.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract through Vyper.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """
  require Logger

  alias Explorer.SmartContract.Vyper.CodeCompiler
  alias Explorer.SmartContract.RustVerifierInterface

  import Explorer.SmartContract.Helper,
    only: [fetch_data_for_verification: 1, prepare_bytecode_for_microservice: 3, contract_creation_input: 1]

  def evaluate_authenticity(_, %{"contract_source_code" => ""}),
    do: {:error, :contract_source_code}

  def evaluate_authenticity(address_hash, params) do
    try do
      evaluate_authenticity_inner(RustVerifierInterface.enabled?(), address_hash, params)
    rescue
      exception ->
        Logger.error(fn ->
          [
            "Error while verifying smart-contract address: #{address_hash}, params: #{inspect(params, limit: :infinity, printable_limit: :infinity)}: ",
            Exception.format(:error, exception, __STACKTRACE__)
          ]
        end)
    end
  end

  def evaluate_authenticity(address_hash, params, files) do
    try do
      if RustVerifierInterface.enabled?() do
        vyper_verify_multipart(params, params["evm_version"], files, address_hash)
      end
    rescue
      exception ->
        Logger.error(fn ->
          [
            "Error while verifying multi-part vyper smart-contract address: #{address_hash}, params: #{inspect(params, limit: :infinity, printable_limit: :infinity)}: ",
            Exception.format(:error, exception)
          ]
        end)
    end
  end

  def evaluate_authenticity_standard_json(%{"address_hash" => address_hash} = params) do
    try do
      if RustVerifierInterface.enabled?() do
        vyper_verify_standard_json(params, address_hash)
      end
    rescue
      exception ->
        Logger.error(fn ->
          [
            "Error while verifying standard-json vyper smart-contract address: #{address_hash}, params: #{inspect(params, limit: :infinity, printable_limit: :infinity)}: ",
            Exception.format(:error, exception)
          ]
        end)
    end
  end

  defp evaluate_authenticity_inner(true, address_hash, params) do
    vyper_verify_multipart(
      params,
      params["evm_version"],
      %{
        "#{params["name"]}.vy" => params["contract_source_code"]
      },
      address_hash
    )
  end

  defp evaluate_authenticity_inner(false, address_hash, params) do
    verify(address_hash, params)
  end

  defp verify(address_hash, params) do
    contract_source_code = Map.fetch!(params, "contract_source_code")
    compiler_version = Map.fetch!(params, "compiler_version")
    constructor_arguments = Map.get(params, "constructor_arguments", "")

    vyper_output =
      CodeCompiler.run(
        compiler_version: compiler_version,
        code: contract_source_code
      )

    compare_bytecodes(
      vyper_output,
      address_hash,
      constructor_arguments
    )
  end

  defp compare_bytecodes({:error, _}, _, _), do: {:error, :compilation}

  defp compare_bytecodes(
         {:ok, %{"abi" => abi, "bytecode" => bytecode}},
         address_hash,
         arguments_data
       ) do
    blockchain_bytecode =
      address_hash
      |> contract_creation_input()
      |> String.trim()

    if String.trim(bytecode <> arguments_data) == blockchain_bytecode do
      {:ok, %{abi: abi}}
    else
      {:error, :generated_bytecode}
    end
  end

  defp vyper_verify_multipart(params, evm_version, files, address_hash) do
    {creation_transaction_input, deployed_bytecode, verifier_metadata} = fetch_data_for_verification(address_hash)

    %{}
    |> prepare_bytecode_for_microservice(creation_transaction_input, deployed_bytecode)
    |> Map.put("evmVersion", evm_version)
    |> Map.put("sourceFiles", files)
    |> Map.put("compilerVersion", params["compiler_version"])
    |> Map.put("interfaces", params["interfaces"] || %{})
    |> RustVerifierInterface.vyper_verify_multipart(verifier_metadata)
  end

  defp vyper_verify_standard_json(params, address_hash) do
    {creation_transaction_input, deployed_bytecode, verifier_metadata} = fetch_data_for_verification(address_hash)

    %{}
    |> prepare_bytecode_for_microservice(creation_transaction_input, deployed_bytecode)
    |> Map.put("compilerVersion", params["compiler_version"])
    |> Map.put("input", params["input"])
    |> RustVerifierInterface.vyper_verify_standard_json(verifier_metadata)
  end
end
