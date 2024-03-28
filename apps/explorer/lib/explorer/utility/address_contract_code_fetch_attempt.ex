defmodule Explorer.Utility.AddressContractCodeFetchAttempt do
  @moduledoc """
  Module is responsible for keeping the the number of retries for
  Indexer.Fetcher.OnDemand.ContractCode.
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @primary_key false
  typed_schema "address_contract_code_fetch_attempts" do
    field(:address_hash, Hash.Address, primary_key: true)
    field(:retries_number, :integer, primary_key: false)

    timestamps()
  end

  @doc false
  def changeset(address_contract_code_fetch_attempt \\ %__MODULE__{}, params) do
    cast(address_contract_code_fetch_attempt, params, [:hash, :retries_number])
  end

  @doc """
  Gets retries number and updated_at for the Explorer.Chain.Address
  """
  @spec get_retries_number(Hash.Address.t()) :: {non_neg_integer(), DateTime.t()}
  def get_retries_number(address_hash) do
    __MODULE__
    |> where([address_contract_code_fetch_attempt], address_contract_code_fetch_attempt.address_hash == ^address_hash)
    |> select(
      [address_contract_code_fetch_attempt],
      {address_contract_code_fetch_attempt.retries_number, address_contract_code_fetch_attempt.updated_at}
    )
    |> Repo.one()
  end

  @doc """
  Deletes row from address_contract_code_fetch_attempts table for the given address
  """
  @spec delete_address_contract_code_fetch_attempt(Hash.Address.t()) :: {non_neg_integer(), nil}
  def delete_address_contract_code_fetch_attempt(address_hash) do
    __MODULE__
    |> where([address_contract_code_fetch_attempt], address_contract_code_fetch_attempt.address_hash == ^address_hash)
    |> Repo.delete_all()
  end

  def insert_retries_number(address_hash) do
    now = DateTime.utc_now()
    params = [%{address_hash: address_hash, inserted_at: now, updated_at: now, retries_number: 1}]

    Repo.insert_all(__MODULE__, params, on_conflict: default_on_conflict(), conflict_target: :address_hash)
  end

  defp default_on_conflict do
    from(
      address_contract_code_fetch_attempt in __MODULE__,
      update: [
        set: [
          retries_number: fragment("? + 1", address_contract_code_fetch_attempt.retries_number),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", address_contract_code_fetch_attempt.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", address_contract_code_fetch_attempt.updated_at)
        ]
      ]
    )
  end
end
