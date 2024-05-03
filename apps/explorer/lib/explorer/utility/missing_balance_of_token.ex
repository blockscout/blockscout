defmodule Explorer.Utility.MissingBalanceOfToken do
  @moduledoc """
  Module is responsible for keeping address hashes of tokens that does not support the balanceOf function
  and the maximum block number for which this function call returned an error.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Repo

  @primary_key false
  typed_schema "missing_balance_of_tokens" do
    field(:block_number, :integer)

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      references: :contract_address_hash,
      primary_key: true,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  @doc false
  def changeset(missing_balance_of_token \\ %__MODULE__{}, params) do
    cast(missing_balance_of_token, params, [:token_contract_address_hash, :block_number])
  end

  @doc """
  Returns all records by provided token contract address hashes
  """
  @spec get_by_hashes([Hash.Address.t()]) :: [%__MODULE__{}]
  def get_by_hashes(token_contract_address_hashes) do
    __MODULE__
    |> where([mbot], mbot.token_contract_address_hash in ^token_contract_address_hashes)
    |> Repo.all()
  end

  @doc """
  Filters provided token balances params by presence of record with the same `token_contract_address_hash`
  and above or equal `block_number` in `missing_balance_of_tokens`.
  """
  @spec filter_token_balances_params([map()]) :: [map()]
  def filter_token_balances_params(params) do
    missing_balance_of_tokens_map =
      params
      |> Enum.map(& &1.token_contract_address_hash)
      |> get_by_hashes()
      |> Enum.map(&{to_string(&1.token_contract_address_hash), &1.block_number})
      |> Map.new()

    Enum.filter(params, fn %{token_contract_address_hash: token_contract_address_hash, block_number: block_number} ->
      case missing_balance_of_tokens_map[to_string(token_contract_address_hash)] do
        nil -> true
        missing_balance_of_block_number -> block_number > missing_balance_of_block_number
      end
    end)
  end

  @doc """
  Inserts new `missing_balance_of_tokens` records by provided params (except for `ERC-404` token type)
  """
  @spec insert_from_params([map()]) :: {non_neg_integer(), nil | [term()]}
  def insert_from_params(token_balance_params) do
    now = DateTime.utc_now()

    params =
      token_balance_params
      |> Enum.reject(&(&1.token_type == "ERC-404"))
      |> Enum.group_by(& &1.token_contract_address_hash, & &1.block_number)
      |> Enum.map(fn {token_contract_address_hash, block_numbers} ->
        {:ok, token_contract_address_hash_casted} = Hash.Address.cast(token_contract_address_hash)

        %{
          token_contract_address_hash: token_contract_address_hash_casted,
          block_number: Enum.max(block_numbers),
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(__MODULE__, params, on_conflict: on_conflict(), conflict_target: :token_contract_address_hash)
  end

  defp on_conflict do
    from(
      mbot in __MODULE__,
      update: [
        set: [
          block_number: fragment("GREATEST(EXCLUDED.block_number, ?)", mbot.block_number),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ]
    )
  end
end
