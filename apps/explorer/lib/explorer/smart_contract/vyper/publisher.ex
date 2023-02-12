defmodule Explorer.SmartContract.Vyper.Publisher do
  @moduledoc """
  Module responsible to control Vyper contract verification.
  """

  import Explorer.SmartContract.Helper, only: [cast_libraries: 1]

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.CompilerVersion
  alias Explorer.SmartContract.Vyper.Verifier

  def publish(address_hash, params) do
    case Verifier.evaluate_authenticity(address_hash, params) do
      {
        :ok,
        %{
          "abi" => abi_string,
          "compilerVersion" => compiler_version,
          "constructorArguments" => constructor_arguments,
          "contractName" => contract_name,
          "fileName" => file_name,
          "sourceFiles" => sources,
          "compilerSettings" => compiler_settings_string
        }
      } ->
        %{^file_name => contract_source_code} = sources

        compiler_settings = Jason.decode!(compiler_settings_string)

        prepared_params =
          %{}
          |> Map.put("compiler_version", compiler_version)
          |> Map.put("constructor_arguments", constructor_arguments)
          |> Map.put("contract_source_code", contract_source_code)
          |> Map.put("evm_version", compiler_settings["evmVersion"] || "istanbul")
          |> Map.put("external_libraries", cast_libraries(compiler_settings["libraries"] || %{}))
          |> Map.put("name", contract_name)

        publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string))

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Unexpected error", nil)}
    end
  end

  def publish(address_hash, params, files) do
    case Verifier.evaluate_authenticity(address_hash, params, files) do
      {
        :ok,
        %{
          "abi" => abi_string,
          "compilerVersion" => compiler_version,
          "constructorArguments" => constructor_arguments,
          "contractName" => contract_name,
          "fileName" => file_name,
          "sourceFiles" => sources,
          "compilerSettings" => compiler_settings_string
        }
      } ->
        secondary_sources =
          for {file, source} <- sources,
              file != file_name,
              do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

        %{^file_name => contract_source_code} = sources

        compiler_settings = Jason.decode!(compiler_settings_string)

        prepared_params =
          %{}
          |> Map.put("compiler_version", compiler_version)
          |> Map.put("constructor_arguments", constructor_arguments)
          |> Map.put("contract_source_code", contract_source_code)
          |> Map.put("external_libraries", cast_libraries(compiler_settings["libraries"] || %{}))
          |> Map.put("name", contract_name)
          |> Map.put("file_path", file_name)
          |> Map.put("secondary_sources", secondary_sources)
          |> Map.put("evm_version", compiler_settings["evmVersion"] || "default")

        publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string))

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Unexpected error", nil)}
    end
  end

  def publish_smart_contract(address_hash, params, abi) do
    attrs = address_hash |> attributes(params, abi)

    Chain.create_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
  end

  defp unverified_smart_contract(address_hash, params, error, error_message) do
    attrs = attributes(address_hash, params)

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error,
        error_message
      )

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, abi \\ %{}) do
    constructor_arguments = params["constructor_arguments"]

    clean_constructor_arguments =
      if constructor_arguments != nil && constructor_arguments != "" do
        constructor_arguments
      else
        nil
      end

    compiler_version = CompilerVersion.get_strict_compiler_version(:vyper, params["compiler_version"])

    %{
      address_hash: address_hash,
      name: "Vyper_contract",
      compiler_version: compiler_version,
      evm_version: params["evm_version"],
      optimization_runs: nil,
      optimization: false,
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: [],
      secondary_sources: [],
      abi: abi,
      verified_via_sourcify: false,
      partially_verified: false,
      is_vyper_contract: true
    }
  end
end
