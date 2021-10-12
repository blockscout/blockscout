# credo:disable-for-this-file
defmodule Explorer.SmartContract.Vyper.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract through Vyper.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """

  alias Explorer.Chain
  alias Explorer.SmartContract.Vyper.CodeCompiler

  def evaluate_authenticity(_, %{"name" => ""}), do: {:error, :name}

  def evaluate_authenticity(_, %{"contract_source_code" => ""}),
    do: {:error, :contract_source_code}

  def evaluate_authenticity(address_hash, params) do
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

  # credo:disable-for-next-line /Complexity/
  defp compare_bytecodes(
         {:ok, %{"abi" => abi, "bytecode" => bytecode}},
         address_hash,
         arguments_data
       ) do
    blockchain_bytecode =
      case Chain.smart_contract_creation_tx_bytecode(address_hash) do
        %{init: init, created_contract_code: _created_contract_code} ->
          init

        _ ->
          nil
      end
      |> String.trim()

    if String.trim(bytecode <> arguments_data) == blockchain_bytecode do
      {:ok, %{abi: abi}}
    else
      {:error, :generated_bytecode}
    end
  end
end
