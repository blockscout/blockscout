defmodule Explorer.SmartContract.Publisher do
  @moduledoc """
  Module responsible to control the contract verification.
  """

  alias Explorer.Chain
  alias Explorer.Chain.SmartContract
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
  def publish(address_hash, params) do
    case Verifier.evaluate_authenticity(address_hash, params) do
      {:ok, %{abi: abi}} ->
        publish_smart_contract(address_hash, params, abi)

      {:error, error} ->
        {:error, unverified_smart_contract(address_hash, params, error)}
    end
  end

  defp publish_smart_contract(address_hash, params, abi) do
    address_hash
    |> attributes(params, abi)
    |> Chain.create_smart_contract()
  end

  defp unverified_smart_contract(address_hash, params, error) do
    attrs = attributes(address_hash, params)

    changeset =
      SmartContract.invalid_contract_changeset(
        %SmartContract{address_hash: address_hash},
        attrs,
        error
      )

    %{changeset | action: :insert}
  end

  defp attributes(address_hash, params, abi \\ %{}) do
    %{
      address_hash: address_hash,
      name: params["name"],
      compiler_version: params["compiler_version"],
      optimization: params["optimization"],
      contract_source_code: params["contract_source_code"],
      abi: abi
    }
  end
end
