defmodule Explorer.SmartContract.Verifier do
  @moduledoc """
  Module responsible to verify the Smart Contract.

  Given a contract source code the bytecode will be generated  and matched
  against the existing Creation Address Bytecode, if it matches the contract is
  then Verified.
  """

  alias Explorer.Chain
  alias Explorer.SmartContract.Solidity.CodeCompiler
  alias Explorer.SmartContract.Verifier.ConstructorArguments

  def evaluate_authenticity(_, %{"name" => ""}), do: {:error, :name}

  def evaluate_authenticity(_, %{"contract_source_code" => ""}),
    do: {:error, :contract_source_code}

  def evaluate_authenticity(address_hash, params) do
    name = Map.fetch!(params, "name")
    contract_source_code = Map.fetch!(params, "contract_source_code")
    optimization = Map.fetch!(params, "optimization")
    compiler_version = Map.fetch!(params, "compiler_version")
    external_libraries = Map.get(params, "external_libraries", %{})
    constructor_arguments = Map.get(params, "constructor_arguments", "")
    evm_version = Map.get(params, "evm_version", "byzantium")
    optimization_runs = Map.get(params, "optimization_runs", 200)

    solc_output =
      CodeCompiler.run(
        name: name,
        compiler_version: compiler_version,
        code: contract_source_code,
        optimize: optimization,
        optimization_runs: optimization_runs,
        evm_version: evm_version,
        external_libs: external_libraries
      )

    case compare_bytecodes(solc_output, address_hash, constructor_arguments) do
      {:error, :generated_bytecode} ->
        next_evm_version = next_evm_version(evm_version)

        second_solc_output =
          CodeCompiler.run(
            name: name,
            compiler_version: compiler_version,
            code: contract_source_code,
            optimize: optimization,
            evm_version: next_evm_version,
            external_libs: external_libraries
          )

        compare_bytecodes(second_solc_output, address_hash, constructor_arguments)

      result ->
        result
    end
  end

  defp compare_bytecodes({:error, :name}, _, _), do: {:error, :name}
  defp compare_bytecodes({:error, _}, _, _), do: {:error, :compilation}

  defp compare_bytecodes({:ok, %{"abi" => abi, "bytecode" => bytecode}}, address_hash, arguments_data) do
    generated_bytecode = extract_bytecode(bytecode)

    "0x" <> blockchain_bytecode =
      address_hash
      |> Chain.smart_contract_bytecode()

    blockchain_bytecode_without_whisper = extract_bytecode(blockchain_bytecode)

    cond do
      generated_bytecode != blockchain_bytecode_without_whisper ->
        {:error, :generated_bytecode}

      !ConstructorArguments.verify(address_hash, arguments_data) ->
        {:error, :constructor_arguments}

      true ->
        {:ok, %{abi: abi}}
    end
  end

  @doc """
  In order to discover the bytecode we need to remove the `swarm source` from
  the hash.

  For more information on the swarm hash, check out:
  https://solidity.readthedocs.io/en/v0.5.3/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
  """
  def extract_bytecode("0x" <> code) do
    "0x" <> extract_bytecode(code)
  end

  def extract_bytecode(code) do
    do_extract_bytecode([], String.downcase(code))
  end

  defp do_extract_bytecode(extracted, remaining) do
    case remaining do
      <<>> ->
        extracted
        |> Enum.reverse()
        |> :binary.list_to_bin()

      "a165627a7a72305820" <> <<_::binary-size(64)>> <> "0029" <> _constructor_arguments ->
        extracted
        |> Enum.reverse()
        |> :binary.list_to_bin()

      <<next::binary-size(2)>> <> rest ->
        do_extract_bytecode([next | extracted], rest)
    end
  end

  def next_evm_version(current_evm_version) do
    [prev_version, last_version] =
      CodeCompiler.allowed_evm_versions()
      |> Enum.reverse()
      |> Enum.take(2)

    if current_evm_version != last_version do
      last_version
    else
      prev_version
    end
  end
end
