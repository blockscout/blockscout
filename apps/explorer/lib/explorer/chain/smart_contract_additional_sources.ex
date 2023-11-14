defmodule Explorer.Chain.SmartContractAdditionalSource do
  @moduledoc """
  The representation of a verified Smart Contract additional sources.
  It is used when contract is verified with Sourcify utility.
  """

  require Logger

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.{Hash, SmartContract}

  @typedoc """
  * `file_name` - the name of the Solidity file with contract code (with extension).
  * `contract_source_code` - the Solidity source code from the file with `file_name`.
  """

  @type t :: %Explorer.Chain.SmartContractAdditionalSource{
          file_name: String.t(),
          contract_source_code: String.t()
        }

  schema "smart_contracts_additional_sources" do
    field(:file_name, :string)
    field(:contract_source_code, :string)

    belongs_to(
      :smart_contract,
      SmartContract,
      foreign_key: :address_hash,
      references: :address_hash,
      type: Hash.Address
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
    |> validate_required([:file_name, :contract_source_code, :address_hash])
    |> unique_constraint(:address_hash)
  end

  def invalid_contract_changeset(%__MODULE__{} = smart_contract_additional_source, attrs, error) do
    validated =
      smart_contract_additional_source
      |> cast(attrs, [
        :file_name,
        :contract_source_code,
        :address_hash
      ])
      |> validate_required([:file_name, :address_hash])

    add_error(validated, :contract_source_code, error_message(error))
  end

  @doc """
  Returns all additional sources for the given smart-contract address hash
  """
  @spec get_contract_additional_sources(SmartContract.t() | nil, Keyword.t()) :: [__MODULE__.t()]
  def get_contract_additional_sources(smart_contract, options) do
    if smart_contract do
      all_additional_sources_query =
        from(
          s in __MODULE__,
          where: s.address_hash == ^smart_contract.address_hash
        )

      all_additional_sources_query
      |> select_repo(options).all()
    else
      []
    end
  end

  defp error_message(_), do: "There was an error validating your contract, please try again."
end
