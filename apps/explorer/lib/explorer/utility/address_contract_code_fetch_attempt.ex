defmodule Explorer.Utility.AddressContractCodeFetchAttempt do
  @moduledoc """
  Module is responsible for keeping the number of retries for
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
    Retrieves the number of retries and the last update timestamp for a given address.

    ## Parameters
    - `address_hash`: The address to query.

    ## Returns
    - `{retries_number, updated_at}`: A tuple containing the number of retries and
      the last update timestamp.
    - `nil`: If no record is found for the given address.
  """
  @spec get_retries_number(Hash.Address.t()) :: {non_neg_integer(), DateTime.t()} | nil
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
    Deletes the entry from the `address_contract_code_fetch_attempts` table that corresponds to the provided address hash.

    ## Parameters
    - `address_hash`: The `t:Explorer.Chain.Hash.Address.t/0` of the address
      whose fetch attempt record should be deleted.

    ## Returns
    A tuple `{count, nil}`, where `count` is the number of records deleted
    (typically 1 if the record existed, 0 otherwise).
  """
  @spec delete(Hash.Address.t()) :: {non_neg_integer(), nil}
  def delete(address_hash) do
    __MODULE__
    |> where([address_contract_code_fetch_attempt], address_contract_code_fetch_attempt.address_hash == ^address_hash)
    |> Repo.delete_all()
  end

  @doc """
    Inserts the number of retries for fetching contract code for a given address.

    ## Parameters
    - `address_hash` - The hash of the address for which the retries number is to be inserted.

    ## Returns
    The result of the insertion operation.
  """
  @spec insert_retries_number(Hash.Address.t()) :: {non_neg_integer(), nil | [term()]}
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
