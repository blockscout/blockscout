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

  Each row names the three participants of the attack, as well as the token
  contract, by their address id — the compact key
  `Explorer.Utility.AddressIdToAddressHash` maintains for every address:

  * `victim_address_id` — the address whose history is being poisoned;
  * `mimic_address_id` — the look-alike counterparty of the transfer;
  * `issuer_address_id` — the sender of the transaction that emitted the
    transfer, when it is known (transfers emitted outside a transaction, as Celo
    has them, carry `nil`).

  The matching `*_address_hash` fields are virtual: `insert_all/1` takes the
  hashes and resolves the ids, and the queries built on `with_address_hashes/1`
  join the mapping back so that readers never see an id.

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
  alias Explorer.Utility.AddressIdToAddressHash

  # `{hash field, id field}` of every participant: the hashes come in, the ids
  # are stored
  @address_fields [
    {:token_contract_address_hash, :token_contract_address_id},
    {:victim_address_hash, :victim_address_id},
    {:mimic_address_hash, :mimic_address_id},
    {:issuer_address_hash, :issuer_address_id}
  ]

  @required_attrs ~w(block_hash log_index block_number token_contract_address_id victim_address_id mimic_address_id score rules)a
  @optional_attrs ~w(transaction_hash issuer_address_id details)a

  @primary_key false
  typed_schema "token_transfer_poisoning_attacks" do
    field(:block_hash, Hash.Full, primary_key: true, null: false)
    field(:log_index, :integer, primary_key: true, null: false)
    field(:transaction_hash, Hash.Full, null: true)
    field(:block_number, :integer, null: false) :: Block.block_number()
    field(:score, :integer, null: false)
    field(:rules, {:array, :string}, null: false)
    field(:details, :map, null: false, default: %{})

    field(:token_contract_address_hash, Hash.Address, virtual: true)
    field(:victim_address_hash, Hash.Address, virtual: true)
    field(:mimic_address_hash, Hash.Address, virtual: true)
    field(:issuer_address_hash, Hash.Address, virtual: true)

    belongs_to(:token_contract_address_mapping, AddressIdToAddressHash,
      foreign_key: :token_contract_address_id,
      references: :address_id,
      type: :integer,
      null: false
    )

    belongs_to(:victim_address_mapping, AddressIdToAddressHash,
      foreign_key: :victim_address_id,
      references: :address_id,
      type: :integer,
      null: false
    )

    belongs_to(:mimic_address_mapping, AddressIdToAddressHash,
      foreign_key: :mimic_address_id,
      references: :address_id,
      type: :integer,
      null: false
    )

    belongs_to(:issuer_address_mapping, AddressIdToAddressHash,
      foreign_key: :issuer_address_id,
      references: :address_id,
      type: :integer,
      null: true
    )

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

  Each entry is a map with the fields of this schema, naming the participants
  by their `*_address_hash` (already cast to `Explorer.Chain.Hash.Address`);
  the address ids are resolved here, creating the mappings that do not exist
  yet, and `inserted_at`/`updated_at` are filled in.
  """
  @spec insert_all([map()]) :: {non_neg_integer(), nil}
  def insert_all([]), do: {0, nil}

  def insert_all(attacks) do
    now = DateTime.utc_now()
    ids_by_hash = address_ids(attacks)

    entries =
      Enum.map(attacks, fn attack ->
        attack
        |> put_address_ids(ids_by_hash)
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
           :token_contract_address_id,
           :victim_address_id,
           :mimic_address_id,
           :issuer_address_id,
           :score,
           :rules,
           :details,
           :updated_at
         ]},
      conflict_target: [:block_hash, :log_index]
    )
  end

  defp address_ids(attacks) do
    attacks
    |> Enum.flat_map(fn attack ->
      Enum.map(@address_fields, fn {hash_field, _id_field} -> Map.get(attack, hash_field) end)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> AddressIdToAddressHash.find_or_create_multiple(true)
  end

  # `find_or_create_multiple/2` keys its map by the string form of the hash
  defp put_address_ids(attack, ids_by_hash) do
    Enum.reduce(@address_fields, attack, fn {hash_field, id_field}, acc ->
      case Map.get(acc, hash_field) do
        nil -> acc
        hash -> Map.put(acc, id_field, Map.fetch!(ids_by_hash, to_string(hash)))
      end
    end)
  end

  @doc """
  Joins the address mappings and fills the virtual `*_address_hash` fields of
  the selected attacks, so that readers get hashes rather than ids.
  """
  @spec with_address_hashes(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def with_address_hashes(query \\ __MODULE__) do
    query
    |> join(:inner, [attack], token_contract in AddressIdToAddressHash,
      as: :token_contract,
      on: token_contract.address_id == attack.token_contract_address_id
    )
    |> join(:inner, [attack], victim in AddressIdToAddressHash,
      as: :victim,
      on: victim.address_id == attack.victim_address_id
    )
    |> join(:inner, [attack], mimic in AddressIdToAddressHash,
      as: :mimic,
      on: mimic.address_id == attack.mimic_address_id
    )
    |> join(:left, [attack], issuer in AddressIdToAddressHash,
      as: :issuer,
      on: issuer.address_id == attack.issuer_address_id
    )
    |> select_merge([token_contract: token_contract, victim: victim, mimic: mimic, issuer: issuer], %{
      token_contract_address_hash: token_contract.address_hash,
      victim_address_hash: victim.address_hash,
      mimic_address_hash: mimic.address_hash,
      issuer_address_hash: issuer.address_hash
    })
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
    |> with_address_hashes()
    |> Chain.select_repo(options).all()
    |> Enum.filter(&MapSet.member?(key_set, {&1.block_hash, &1.log_index}))
    |> Map.new(&{{&1.block_hash, &1.log_index}, &1})
  end
end
