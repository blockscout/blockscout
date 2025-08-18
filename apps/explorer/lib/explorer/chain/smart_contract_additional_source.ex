defmodule Explorer.Chain.SmartContractAdditionalSource do
  @moduledoc """
  The representation of a verified Smart Contract additional sources.
  It is used when contract is verified with Sourcify utility.
  """

  require Logger

  use Explorer.Schema

  alias Explorer.Chain.{Hash, SmartContract}

  @typedoc """
  * `file_name` - the name of the Solidity file with contract code (with extension).
  * `contract_source_code` - the Solidity source code from the file with `file_name`.
  * `address_hash` - foreign key for `smart_contract`.
  """
  typed_schema "smart_contracts_additional_sources" do
    field(:file_name, :string, null: false)
    field(:contract_source_code, :string, null: false)

    # TODO: Why not use smart_contract_id?
    belongs_to(
      :smart_contract,
      SmartContract,
      foreign_key: :address_hash,
      references: :address_hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = smart_contract_additional_source, attrs) do
    smart_contract_additional_source
    |> cast(attrs, [
      :file_name,
      :contract_source_code,
      :address_hash
    ])
    |> validate_required([:address_hash, :file_name, :contract_source_code])
    |> unique_constraint([:address_hash, :file_name])
  end

  def invalid_contract_changeset(%__MODULE__{} = smart_contract_additional_source, attrs, error) do
    validated =
      smart_contract_additional_source
      |> cast(attrs, [
        :address_hash,
        :file_name,
        :contract_source_code
      ])
      |> validate_required([:address_hash, :file_name])

    add_error(validated, :contract_source_code, error_message(error))
  end

  defp error_message(_), do: "There was an error validating your contract, please try again."
end
