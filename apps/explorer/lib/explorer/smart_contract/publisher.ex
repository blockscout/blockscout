defmodule Explorer.SmartContract.Publisher do
  @moduledoc """
  Module responsible to control the contract verification.
  """

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Solidity.CompilerVersion
  alias Explorer.SmartContract.Verifier

  @doc """
  Evaluates smart contract authenticity and saves its details.

  ## Examples
      Explorer.SmartContract.Publisher.publish(
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
      {:ok, %{abi: abi, contructor_arguments: contructor_arguments}} ->
        params_with_contructor_arguments =
          Map.put(params_with_external_libaries, "constructor_arguments", contructor_arguments)

        publish_smart_contract(address_hash, params_with_contructor_arguments, abi)

      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params_with_external_libaries, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libaries, error, nil)}

      {:error, error, error_message} ->
        {:error, unverified_smart_contract(address_hash, params_with_external_libaries, error, error_message)}
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

    prepared_external_libraries = prepare_external_libraies(params["external_libraries"])

    compiler_version = CompilerVersion.get_strict_compiler_version(params["compiler_version"])

    %{
      address_hash: address_hash,
      name: params["name"],
      compiler_version: compiler_version,
      evm_version: params["evm_version"],
      optimization_runs: params["optimization_runs"],
      optimization: params["optimization"],
      contract_source_code: params["contract_source_code"],
      constructor_arguments: clean_constructor_arguments,
      external_libraries: prepared_external_libraries,
      secondary_sources: params["secondary_sources"],
      abi: abi,
      verified_via_sourcify: params["verified_via_sourcify"]
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
      Enum.reduce(1..10, %{}, fn number, acc ->
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
