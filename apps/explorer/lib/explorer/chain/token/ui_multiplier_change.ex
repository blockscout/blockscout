# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Token.UIMultiplierChange do
  @moduledoc """
  History of the [ERC-8056](https://eips.ethereum.org/EIPS/eip-8056) multiplier
  of a token, one row per `UIMultiplierUpdated` log.

  `Explorer.Chain.Token` only carries the multiplier a token has *now*, which is
  all that is needed to display balances. Amounts that belong to a moment in the
  past — the amount of a token transfer, above all — have to be displayed with
  the multiplier that was in force back then, and that is what this table
  answers.

  Resolving a moment takes both coordinates of a change, because a change is
  announced before it applies:

  * the log that announced it fixes *from when the schedule is known*, ordered
    by `{block_number, log_index}`;
  * `effective_at` fixes *from when the new value applies*.

  So the multiplier at some point is the value of the last change announced at
  or before that point, picking `new_multiplier` once `effective_at` has passed
  and `old_multiplier` until then — the same branch the contract itself takes.
  Keeping both values also makes a change that gets superseded before maturing
  resolve correctly: it is simply never the last one announced.

  For an honest token the history is a handful of rows — the multiplier exists
  for rare events such as stock splits — so `for_tokens/2` loads whole histories
  at once and `at/4` resolves in memory rather than querying per token transfer.
  Nothing on chain enforces that restraint, though, so a token is refused past
  `@max_changes_per_token` rows and no longer resolved at all: without the cap a
  contract could emit the event in a loop and make every API page holding one of
  its transfers load an arbitrarily large history.

  Rows carry the hash of the block their log came from and are only resolved
  while that block is consensus, so a reorg that takes the event away takes its
  effect on displayed amounts with it.
  """

  use Explorer.Schema

  require Logger

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Block, Hash, Token, TokenTransfer, Transaction}

  @max_changes_per_token 1_000

  @required_attrs ~w(token_contract_address_hash block_number block_hash log_index old_multiplier new_multiplier effective_at)a

  @primary_key false
  typed_schema "token_ui_multiplier_changes" do
    field(:block_number, :integer, primary_key: true, null: false) :: Block.block_number()
    field(:log_index, :integer, primary_key: true, null: false)
    field(:old_multiplier, :decimal, null: false)
    field(:new_multiplier, :decimal, null: false)
    field(:effective_at, :utc_datetime_usec, null: false)

    belongs_to(
      :block,
      Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(
      :token,
      Token,
      foreign_key: :token_contract_address_hash,
      primary_key: true,
      references: :contract_address_hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  @doc false
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = change, attrs \\ %{}) do
    change
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:token_contract_address_hash, :block_number, :log_index])
  end

  @doc """
  Records the given changes, as parsed by
  `Explorer.Chain.Token.ScaledUIAmount.parse_ui_multiplier_updated/1`.

  Replaying a log, or a reorg putting a different one at the same position, has
  to converge on the current content of the block, so an existing row is
  overwritten rather than kept.
  """
  @spec insert_changes([map()]) :: {non_neg_integer(), nil}
  def insert_changes([]), do: {0, nil}

  def insert_changes(changes) do
    now = DateTime.utc_now()

    entries =
      changes
      |> reject_over_cap()
      |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

    Repo.safe_insert_all(__MODULE__, entries,
      on_conflict: {:replace, [:block_hash, :old_multiplier, :new_multiplier, :effective_at, :updated_at]},
      conflict_target: [:token_contract_address_hash, :block_number, :log_index]
    )
  end

  defp reject_over_cap(changes) do
    counts = recorded_counts(changes)

    Enum.reject(changes, &over_cap?(&1, counts))
  end

  defp over_cap?(change, counts) do
    if Map.get(counts, change.token_contract_address_hash, 0) >= @max_changes_per_token do
      Logger.warning(fn ->
        "Refusing an ERC-8056 multiplier change of #{change.token_contract_address_hash}: " <>
          "already at the #{@max_changes_per_token} row cap"
      end)

      true
    else
      false
    end
  end

  defp recorded_counts(changes) do
    hashes = changes |> Enum.map(& &1.token_contract_address_hash) |> Enum.uniq()

    __MODULE__
    |> where([change], change.token_contract_address_hash in ^hashes)
    |> group_by([change], change.token_contract_address_hash)
    |> select([change], {change.token_contract_address_hash, count(change.log_index)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Loads the full multiplier history of the given token contracts, grouped by
  contract and ordered the way `at/4` expects.

  Returns an empty map without touching the database when no contract is given,
  which is the case for every page that has no ERC-8056 token on it.
  """
  @spec for_tokens([Hash.Address.t()], keyword()) :: %{Hash.Address.t() => [t()]}
  def for_tokens(token_contract_address_hashes, options \\ [])

  def for_tokens([], _options), do: %{}

  def for_tokens(token_contract_address_hashes, options) do
    repo = Chain.select_repo(options)

    case resolvable_tokens(token_contract_address_hashes, repo) do
      [] ->
        %{}

      hashes ->
        __MODULE__
        |> join(:inner, [change], block in assoc(change, :block))
        |> where([change, block], change.token_contract_address_hash in ^hashes and block.consensus == true)
        |> order_by([change], asc: change.block_number, asc: change.log_index)
        |> repo.all()
        |> Enum.group_by(& &1.token_contract_address_hash)
    end
  end

  defp resolvable_tokens(token_contract_address_hashes, repo) do
    __MODULE__
    |> where([change], change.token_contract_address_hash in ^token_contract_address_hashes)
    |> group_by([change], change.token_contract_address_hash)
    |> having([change], count(change.log_index) <= @max_changes_per_token)
    |> select([change], change.token_contract_address_hash)
    |> repo.all()
  end

  @doc """
  Returns the multiplier that was in force at the given point of the chain, or
  `nil` when it cannot be told.

  `changes` is the history of one token as returned by `for_tokens/2`, and
  `block_number`/`log_index` locate the log the amount belongs to, so that a
  change announced earlier in the very same block is already accounted for.

  A point that precedes every known change resolves to the value the earliest
  change replaced, which is exactly the multiplier the token had since it was
  deployed — provided the history reaches that far back. On a chain indexed
  before ERC-8056 support existed that holds once
  `Explorer.Migrator.BackfillScaledUIAmountTokens` has worked through the
  `UIMultiplierUpdated` logs already stored.
  """
  @spec at([t()], Block.block_number(), non_neg_integer(), DateTime.t() | nil) :: Decimal.t() | nil
  def at(changes, block_number, log_index, timestamp)

  def at([], _block_number, _log_index, _timestamp), do: nil

  # without knowing when the amount happened there is no way to tell whether a
  # scheduled change had already matured, and a guess would be silently wrong
  def at(_changes, _block_number, _log_index, nil), do: nil

  def at(changes, block_number, log_index, timestamp) do
    case Enum.take_while(changes, &announced_by?(&1, block_number, log_index)) do
      [] -> changes |> hd() |> Map.fetch!(:old_multiplier)
      announced -> announced |> List.last() |> in_force_at(timestamp)
    end
  end

  @doc """
  Fills the virtual `ui_multiplier` of the given token transfers with the
  multiplier that was in force when each of them happened.

  Costs one query for the whole collection, and none at all — the usual case —
  when it holds no transfer of an ERC-8056 token. Requires `:token` to be
  preloaded, plus either `:block` or `:transaction`, since the moment of the
  transfer decides whether a scheduled change had already matured by then.

  `nil` entries are passed through, so a collection where a token transfer is
  optional can be handed over as is and zipped back afterwards.
  """
  @spec put_ui_multipliers([TokenTransfer.t() | nil], keyword()) :: [TokenTransfer.t() | nil]
  def put_ui_multipliers(token_transfers, options \\ []) do
    scaled_token_hashes =
      token_transfers
      |> Enum.filter(&match?(%TokenTransfer{token: %Token{ui_multiplier: %Decimal{}}}, &1))
      |> Enum.map(& &1.token.contract_address_hash)
      |> Enum.uniq()

    case for_tokens(scaled_token_hashes, options) do
      changes_by_token when map_size(changes_by_token) == 0 ->
        token_transfers

      changes_by_token ->
        Enum.map(token_transfers, &put_ui_multiplier(&1, changes_by_token))
    end
  end

  defp put_ui_multiplier(%TokenTransfer{token: %Token{} = token} = token_transfer, changes_by_token) do
    case changes_by_token[token.contract_address_hash] do
      nil ->
        token_transfer

      changes ->
        multiplier =
          at(changes, token_transfer.block_number, token_transfer.log_index, timestamp_of(token_transfer))

        %{token_transfer | ui_multiplier: multiplier}
    end
  end

  defp put_ui_multiplier(token_transfer, _changes_by_token), do: token_transfer

  defp timestamp_of(%TokenTransfer{block: %Block{timestamp: timestamp}}), do: timestamp

  defp timestamp_of(%TokenTransfer{transaction: %Transaction{block_timestamp: timestamp}}) when not is_nil(timestamp),
    do: timestamp

  defp timestamp_of(%TokenTransfer{transaction: %Transaction{block: %Block{timestamp: timestamp}}}), do: timestamp

  defp timestamp_of(_token_transfer), do: nil

  defp announced_by?(change, block_number, log_index) do
    {change.block_number, change.log_index} <= {block_number, log_index}
  end

  defp in_force_at(change, timestamp) do
    if DateTime.compare(timestamp, change.effective_at) == :lt do
      change.old_multiplier
    else
      change.new_multiplier
    end
  end
end
