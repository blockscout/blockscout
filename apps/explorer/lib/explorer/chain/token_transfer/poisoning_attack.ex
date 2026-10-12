# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack do
  @moduledoc """
  A token transfer identified as an address poisoning attack, one row per
  flagged transfer log.

  Address poisoning plants fake or dust token transfers into the history of a
  victim so that a look-alike address (the *mimic*) shows up next to a genuine
  past recipient, hoping the victim copies the wrong one later. Detection runs
  in the indexer right after a block is imported: every fungible token transfer
  is scored against the weighted rule set of
  `Explorer.Chain.TokenTransfer.PoisoningAttack.Rules`, and transfers whose
  score reaches the configured threshold are recorded here. The settings are
  listed in `Explorer.Chain.TokenTransfer.PoisoningAttack.Config`.

  Each row names the three participants of the attack:

  * `victim_address_hash` — the address whose history is being poisoned;
  * `mimic_address_hash` — the look-alike counterparty of the transfer;
  * `issuer_address_hash` — the sender of the transaction that emitted the
    transfer, when it is known (transfers emitted outside a transaction, as Celo
    has them, carry `nil`).

  `rules` lists the names of the rules that fired and `details` carries what
  each of them matched, so the API can explain the verdict.

  Rows are keyed by the block hash and log index of the transfer and are never
  deleted on a reorg: a transfer of a block that lost consensus is not listed
  anywhere, so its row is simply never joined. A re-imported block overwrites
  the row.
  """

  use Explorer.Schema

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Hash, TokenTransfer, Transaction}

  @required_attrs ~w(block_hash log_index block_number token_contract_address_hash victim_address_hash mimic_address_hash score rules)a
  @optional_attrs ~w(transaction_hash issuer_address_hash details)a

  @primary_key false
  typed_schema "token_transfer_poisoning_attacks" do
    field(:block_hash, Hash.Full, primary_key: true, null: false)
    field(:log_index, :integer, primary_key: true, null: false)
    field(:transaction_hash, Hash.Full, null: true)
    field(:block_number, :integer, null: false) :: Block.block_number()
    field(:token_contract_address_hash, Hash.Address, null: false)
    field(:victim_address_hash, Hash.Address, null: false)
    field(:mimic_address_hash, Hash.Address, null: false)
    field(:issuer_address_hash, Hash.Address, null: true)
    field(:score, :integer, null: false)
    field(:rules, {:array, :string}, null: false)
    field(:details, :map, null: false, default: %{})

    timestamps()
  end

  @doc false
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = attack, attrs \\ %{}) do
    attack
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:block_hash, :log_index])
  end

  @doc """
  Records the given attacks, overwriting an existing row of the same transfer.

  Each entry is a map with the fields of this schema (hashes already cast to
  their `Explorer.Chain.Hash` structs); `inserted_at`/`updated_at` are filled in
  here.
  """
  @spec insert_all([map()]) :: {non_neg_integer(), nil}
  def insert_all([]), do: {0, nil}

  def insert_all(attacks) do
    now = DateTime.utc_now()

    entries =
      Enum.map(attacks, fn attack ->
        attack
        |> Map.take(@required_attrs ++ @optional_attrs)
        |> Map.put_new(:details, %{})
        |> Map.merge(%{inserted_at: now, updated_at: now})
      end)

    Repo.safe_insert_all(__MODULE__, entries,
      on_conflict:
        {:replace,
         [
           :transaction_hash,
           :block_number,
           :token_contract_address_hash,
           :victim_address_hash,
           :mimic_address_hash,
           :issuer_address_hash,
           :score,
           :rules,
           :details,
           :updated_at
         ]},
      conflict_target: [:block_hash, :log_index]
    )
  end

  @doc """
  Fills the virtual `poisoning_attack` of the given token transfers with their
  recorded attack, or `nil` when the transfer was not flagged.

  Costs a single query for the whole collection and none at all for an empty
  one. `nil` entries are passed through untouched.
  """
  @spec preload_for_token_transfers([TokenTransfer.t() | nil], keyword()) :: [TokenTransfer.t() | nil]
  def preload_for_token_transfers(token_transfers, options \\ [])

  def preload_for_token_transfers([], _options), do: []

  def preload_for_token_transfers(token_transfers, options) do
    keys =
      token_transfers
      |> Enum.filter(&match?(%TokenTransfer{block_hash: %Hash{}, log_index: log_index} when is_integer(log_index), &1))
      |> Enum.map(&{&1.block_hash, &1.log_index})
      |> Enum.uniq()

    attacks_by_key = fetch_by_keys(keys, options)

    Enum.map(token_transfers, fn
      %TokenTransfer{block_hash: block_hash, log_index: log_index} = token_transfer ->
        %{token_transfer | poisoning_attack: Map.get(attacks_by_key, {block_hash, log_index})}

      other ->
        other
    end)
  end

  @doc """
  Fills the verdicts of the token transfers preloaded on a transaction.
  """
  @spec preload_for_transaction(Transaction.t(), keyword()) :: Transaction.t()
  def preload_for_transaction(transaction, options \\ [])

  def preload_for_transaction(%Transaction{token_transfers: [_ | _] = token_transfers} = transaction, options) do
    %{transaction | token_transfers: preload_for_token_transfers(token_transfers, options)}
  end

  def preload_for_transaction(transaction, _options), do: transaction

  defp fetch_by_keys([], _options), do: %{}

  defp fetch_by_keys(keys, options) do
    {block_hashes, log_indexes} = Enum.unzip(keys)
    key_set = MapSet.new(keys)

    __MODULE__
    |> where([attack], attack.block_hash in ^Enum.uniq(block_hashes) and attack.log_index in ^Enum.uniq(log_indexes))
    |> Chain.select_repo(options).all()
    |> Enum.filter(&MapSet.member?(key_set, {&1.block_hash, &1.log_index}))
    |> Map.new(&{{&1.block_hash, &1.log_index}, &1})
  end
end
