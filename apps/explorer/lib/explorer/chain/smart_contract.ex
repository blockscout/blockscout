defmodule Explorer.Chain.SmartContract do
  @moduledoc """
  The representation of a verified Smart Contract.

  "A contract in the sense of Solidity is a collection of code (its functions)
  and data (its state) that resides at a specific address on the Ethereum
  blockchain."
  http://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html
  """

  alias Explorer.Chain.{Address, Hash}

  use Explorer.Schema

  @type t :: %Explorer.Chain.SmartContract{
          name: String.t(),
          compiler_version: String.t(),
          optimization: boolean,
          contract_source_code: String.t(),
          abi: {:array, :map}
        }

  schema "smart_contracts" do
    field(:name, :string)
    field(:compiler_version, :string)
    field(:optimization, :boolean)
    field(:contract_source_code, :string)
    field(:abi, {:array, :map})

    belongs_to(
      :address,
      Address,
      foreign_key: :address_hash,
      references: :hash,
      type: Hash.Address
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = smart_contract, attrs) do
    smart_contract
    |> cast(attrs, [:name, :compiler_version, :optimization, :contract_source_code, :address_hash, :abi])
    |> validate_required([:name, :compiler_version, :optimization, :contract_source_code, :abi, :address_hash])
    |> unique_constraint(:address_hash)
  end

  def invalid_contract_changeset(%__MODULE__{} = smart_contract, attrs, error) do
    smart_contract
    |> cast(attrs, [:name, :compiler_version, :optimization, :contract_source_code, :address_hash])
    |> validate_required([:name, :compiler_version, :optimization, :address_hash])
    |> add_error(:contract_source_code, error_message(error))
  end

  defp error_message(:compilation), do: "There was an error compiling your contract."
  defp error_message(:generated_bytecode), do: "Bytecode does not match, please try again."
  defp error_message(:name), do: "Wrong contract name, please try again."
  defp error_message(_), do: "There was an error validating your contract, please try again."
end
