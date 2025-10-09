defmodule Explorer.Utility.TokenInstanceMetadataRefetchAttempt do
  @moduledoc """
  Module is responsible for keeping the number of retries for
  Indexer.Fetcher.OnDemand.TokenInstanceMetadataRefetch.
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @primary_key false
  typed_schema "token_instance_metadata_refetch_attempts" do
    field(:token_contract_address_hash, Hash.Address, primary_key: true)
    field(:token_id, :decimal, primary_key: true)
    field(:retries_number, :integer, primary_key: false)

    timestamps()
  end

  @doc false
  def changeset(token_instance_metadata_refetch_attempt \\ %__MODULE__{}, params) do
    cast(token_instance_metadata_refetch_attempt, params, [:hash, :retries_number])
  end

  @doc """
  Gets retries number and updated_at for given token contract Explorer.Chain.Address and token_id
  """
  @spec get_retries_number(Hash.Address.t(), non_neg_integer()) :: {non_neg_integer(), DateTime.t()} | nil
  def get_retries_number(token_contract_address_hash, token_id) do
    __MODULE__
    |> where(
      [token_instance_metadata_refetch_attempt],
      token_instance_metadata_refetch_attempt.token_contract_address_hash == ^token_contract_address_hash
    )
    |> where([token_instance_metadata_refetch_attempt], token_instance_metadata_refetch_attempt.token_id == ^token_id)
    |> select(
      [token_instance_metadata_refetch_attempt],
      {token_instance_metadata_refetch_attempt.retries_number, token_instance_metadata_refetch_attempt.updated_at}
    )
    |> Repo.one()
  end

  @doc """
  Inserts the number of retries for fetching token instance metadata into the database.

  ## Parameters
    - `token_contract_address_hash` - The hash of the token contract address.
    - `token_id` - The ID of the token instance.

  ## Returns
    The result of the insertion operation.

  """
  @spec insert_retries_number(Hash.Address.t(), non_neg_integer()) :: {non_neg_integer(), nil | [term()]}
  def insert_retries_number(token_contract_address_hash, token_id) do
    now = DateTime.utc_now()

    params = [
      %{
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id,
        inserted_at: now,
        updated_at: now,
        retries_number: 1
      }
    ]

    Repo.insert_all(__MODULE__, params,
      on_conflict: default_on_conflict(),
      conflict_target: [:token_contract_address_hash, :token_id]
    )
  end

  defp default_on_conflict do
    from(
      token_instance_metadata_refetch_attempt in __MODULE__,
      update: [
        set: [
          retries_number: fragment("? + 1", token_instance_metadata_refetch_attempt.retries_number),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", token_instance_metadata_refetch_attempt.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", token_instance_metadata_refetch_attempt.updated_at)
        ]
      ]
    )
  end
end
