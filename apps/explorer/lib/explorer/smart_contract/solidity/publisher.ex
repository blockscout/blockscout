defmodule Explorer.SmartContract.Solidity.Publisher do
  @moduledoc """
  Module responsible to control the contract verification.
  """

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.{CompilerVersion, Helper}
  alias Explorer.SmartContract.Solidity.Verifier

  @doc """
  Evaluates smart contract authenticity and saves its details.

  ## Examples
      Explorer.SmartContract.Solidity.Publisher.publish(
        "0x0f95fa9bc0383e699325f2658d04e8d96d87b90c",
        %{
          "compiler_version" => "0.4.24",
          "contract_source_code" => "pragma solidity ^0.4.24; contract SimpleStorage { uint storedData; function set(uint x) public { storedData = x; } function get() public constant returns (uint) { return storedData; } }",
          "name" => "SimpleStorage",
          "optimization" => false
        }
      )
      #=> {:ok, %Explorer.Chain.SmartContract{}}

  """
  def publish(address_hash, params, external_libraries \\ %{}) do
    params_with_external_libaries = add_external_libraries(params, external_libraries)

    case Verifier.evaluate_authenticity(address_hash, params_with_external_libaries) do
      {
        :ok,
        %{
          "abi" => abi_string,
          "compiler_version" => _,
          "constructor_arguments" => _,
          "contract_libraries" => contract_libraries,
          "contract_name" => contract_name,
          "evm_version" => _,
          "file_name" => file_name,
          "optimization" => _,
          "optimization_runs" => _,
          "sources" => sources
        } = result_params
      } ->
        %{^file_name => contract_source_code} = sources

        prepared_params =
          result_params
          |> Map.put("contract_source_code", contract_source_code)
          |> Map.put("external_libraries", contract_libraries)
          |> Map.put("name", contract_name)

        publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string || "null"))

      {:ok, %{abi: abi, constructor_arguments: constructor_arguments}} ->
        params_with_constructor_arguments =
          Map.put(params_with_external_libaries, "constructor_arguments", constructor_arguments)

        publish_smart_contract(address_hash, params_with_constructor_arguments, abi)

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params_with_external_libaries, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libaries, error, nil)}

      {:error, error, error_message} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libaries, error, error_message)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libaries, "Unexpected error", nil)}
    end
  end

  def publish_with_standard_json_input(%{"address_hash" => address_hash} = params, json_input) do
    case Verifier.evaluate_authenticity_via_standard_json_input(address_hash, params, json_input) do
      {:ok,
       %{
         "abi" => _,
         "compiler_version" => _,
         "constructor_arguments" => _,
         "contract_libraries" => _,
         "contract_name" => _,
         "evm_version" => _,
         "file_name" => _,
         "optimization" => _,
         "optimization_runs" => _,
         "sources" => _
       } = result_params} ->
        proccess_rust_verifier_response(result_params, address_hash)

      {:ok, %{abi: abi, constructor_arguments: constructor_arguments}, additional_params} ->
        params_with_constructor_arguments =
          params
          |> Map.put("constructor_arguments", constructor_arguments)
          |> Map.merge(additional_params)

        publish_smart_contract(address_hash, params_with_constructor_arguments, abi)

      {:ok, %{abi: abi}, additional_params} ->
        merged_params = Map.merge(params, additional_params)
        publish_smart_contract(address_hash, merged_params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil, true)}

      {:error, error, error_message} ->
        {:error, unverified_smart_contract(address_hash, params, error, error_message, true)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Failed to verify", nil, true)}
    end
  end

  def publish_with_multi_part_files(%{"address_hash" => address_hash} = params, external_libraries, files) do
    params_with_external_libaries = add_external_libraries(params, external_libraries)

    case Verifier.evaluate_authenticity_via_multi_part_files(address_hash, params_with_external_libaries, files) do
      {:ok,
       %{
         "abi" => _,
         "compiler_version" => _,
         "constructor_arguments" => _,
         "contract_libraries" => _,
         "contract_name" => _,
         "evm_version" => _,
         "file_name" => _,
         "optimization" => _,
         "optimization_runs" => _,
         "sources" => _
       } = result_params} ->
        proccess_rust_verifier_response(result_params, address_hash)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error, nil, true)}

      _ ->
        {:error, unverified_smart_contract(address_hash, params, "Failed to verify", nil, true)}
    end
  end

  def proccess_rust_verifier_response(
        %{
          "abi" => abi_string,
          "compiler_version" => _,
          "constructor_arguments" => _,
          "contract_libraries" => contract_libraries,
          "contract_name" => contract_name,
          "evm_version" => _,
          "file_name" => file_name,
          "optimization" => _,
          "optimization_runs" => _,
          "sources" => sources
        } = result_params,
        address_hash
      ) do
    secondary_sources =
      for {file, source} <- sources,
          file != file_name,
          do: %{"file_name" => file, "contract_source_code" => source, "address_hash" => address_hash}

    %{^file_name => contract_source_code} = sources

    prepared_params =
      result_params
      |> Map.put("contract_source_code", contract_source_code)
      |> Map.put("external_libraries", contract_libraries)
      |> Map.put("name", contract_name)
      |> Map.put("file_path", file_name)
      |> Map.put("secondary_sources", secondary_sources)

    publish_smart_contract(address_hash, prepared_params, Jason.decode!(abi_string))
  end

  def publish_smart_contract(address_hash, params, abi) do
    attrs = address_hash |> attributes(params, abi)

    create_or_update_smart_contract(address_hash, attrs)
  end

  def publish_smart_contract(address_hash, params, abi, file_path) do
    attrs = address_hash |> attributes(params, file_path, abi)

    create_or_update_smart_contract(address_hash, attrs)
  end

  defp create_or_update_smart_contract(address_hash, attrs) do
    if Chain.smart_contract_verified?(address_hash) do
      Chain.update_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
    else
      Chain.create_smart_contract(attrs, attrs.external_libraries, attrs.secondary_sources)
    end
  end

  defp unverified_smart_contract(address_hash, params, error, error_message, json_verification \\ false) do
    attrs =
      address_hash
      |> attributes(params)
      |> Helper.add_contract_code_md5()

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error,
        error_message,
        json_verification
      )

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, file_path, abi) do
    Map.put(attributes(address_hash, params, abi), :file_path, file_path)
  end

  defp attributes(address_hash, params, abi \\ %{}) do
    constructor_arguments = params["constructor_arguments"]

    clean_constructor_arguments =
      if constructor_arguments != nil && constructor_arguments != "" do
        constructor_arguments
      else
        nil
      end

    prepared_external_libraries = prepare_external_libraies(params["external_libraries"])

    compiler_version = CompilerVersion.get_strict_compiler_version(:solc, params["compiler_version"])

    %{
      address_hash: address_hash,
      name: params["name"],
      file_path: params["file_path"],
      compiler_version: compiler_version,
      evm_version: params["evm_version"],
      optimization_runs: params["optimization_runs"],
      optimization: params["optimization"],
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: prepared_external_libraries,
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: params["verified_via_sourcify"],
      partially_verified: params["partially_verified"],
      is_vyper_contract: false,
      autodetect_constructor_args: params["autodetect_constructor_args"],
      is_yul: params["is_yul"] || false
    }
  end

  defp prepare_external_libraies(nil), do: []

  defp prepare_external_libraies(map) do
    map
    |> Enum.map(fn {key, value} ->
      %{name: key, address_hash: value}
    end)
  end

  defp add_external_libraries(params, external_libraries) do
    clean_external_libraries =
      Enum.reduce(1..Application.get_env(:block_scout_web, :verification_max_libraries), %{}, fn number, acc ->
        address_key = "library#{number}_address"
        name_key = "library#{number}_name"

        address = external_libraries[address_key]
        name = external_libraries[name_key]

        if is_nil(address) || address == "" || is_nil(name) || name == "" do
          acc
        else
          Map.put(acc, name, address)
        end
      end)

    Map.put(params, "external_libraries", clean_external_libraries)
  end
end
