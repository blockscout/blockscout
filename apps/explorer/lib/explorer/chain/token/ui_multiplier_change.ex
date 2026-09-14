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

  alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Chain.{Block, Hash, Token, TokenTransfer, Transaction}

  @typedoc """
  One row of the history as `paginated_for_token/2` returns it: the change
  itself plus the timestamp of the block that announced it.
  """
  @type page_entry :: %{
          block_number: Block.block_number(),
          block_hash: Hash.Full.t(),
          timestamp: DateTime.t(),
          transaction_hash: Hash.Full.t() | nil,
          log_index: non_neg_integer(),
          old_multiplier: Decimal.t(),
          new_multiplier: Decimal.t(),
          effective_at: DateTime.t()
        }

  @max_changes_per_token 1_000

  @required_attrs ~w(token_contract_address_hash block_number block_hash log_index old_multiplier new_multiplier effective_at)a

  # The hash of the transaction the log came from is not part of what resolves a
  # multiplier, it is carried for display only, and rows recorded before the
  # column existed do not have it — hence optional rather than required.
  @optional_attrs ~w(transaction_hash)a

  @primary_key false
  typed_schema "token_ui_multiplier_changes" do
    field(:block_number, :integer, primary_key: true, null: false) :: Block.block_number()
    field(:log_index, :integer, primary_key: true, null: false)
    field(:transaction_hash, Hash.Full, null: true)
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
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:token_contract_address_hash, :block_number, :log_index])
  end

  @doc """
  Records the given changes, as parsed by
  `Explorer.Chain.Token.ScaledUIAmount.parse_ui_multiplier_updated/1`.

  Replaying a log, or a reorg putting a different one at the same position, has
  to converge on the current content of the block, so an existing row is
  overwritten rather than kept.

  The hashes of a change may arrive either as `0x`-prefixed strings or as
  already cast structs, depending on which producer parsed the log, and both
  shapes are accepted.
  """
  @spec insert_changes([map()]) :: {non_neg_integer(), nil}
  def insert_changes([]), do: {0, nil}

  def insert_changes(changes) do
    now = DateTime.utc_now()

    changes
    |> Enum.flat_map(&cast_hashes/1)
    |> reject_over_cap()
    |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))
    |> insert_entries()
  end

  defp insert_entries([]), do: {0, nil}

  defp insert_entries(entries) do
    Repo.safe_insert_all(__MODULE__, entries,
      on_conflict:
        {:replace, [:block_hash, :transaction_hash, :old_multiplier, :new_multiplier, :effective_at, :updated_at]},
      conflict_target: [:token_contract_address_hash, :block_number, :log_index]
    )
  end

  # `Indexer.Transform.TokenTransfers` takes the hashes straight off the log,
  # where they are still the strings the node answered with, while
  # `Explorer.Migrator.BackfillScaledUIAmountTokens` reads its logs through Ecto
  # and gets them as structs. `insert_all/3` dumps values rather than casting
  # them the way a changeset would, and dumping a string raises — taking the
  # caller down with it, along with everything else it was about to write — so
  # both shapes are cast here, at the one point both producers go through.
  defp cast_hashes(change) do
    with {:ok, token_contract_address_hash} <- Hash.Address.cast(change.token_contract_address_hash),
         {:ok, block_hash} <- Hash.Full.cast(change.block_hash),
         {:ok, transaction_hash} <- cast_transaction_hash(change) do
      [
        Map.merge(change, %{
          token_contract_address_hash: token_contract_address_hash,
          block_hash: block_hash,
          transaction_hash: transaction_hash
        })
      ]
    else
      :error ->
        Logger.error(fn ->
          "Refusing an ERC-8056 multiplier change that carries an unparsable hash: #{inspect(change)}"
        end)

        []
    end
  end

  # A log of a chain that keeps some of them outside a transaction — Celo does —
  # has no transaction hash, and the column it is displayed from is nullable for
  # that reason as much as for the rows recorded before it existed. A change
  # that does not carry the key at all is treated the same way rather than
  # taking down the batch it arrived in.
  defp cast_transaction_hash(%{transaction_hash: transaction_hash}) when not is_nil(transaction_hash),
    do: Hash.Full.cast(transaction_hash)

  defp cast_transaction_hash(_change), do: {:ok, nil}

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
  Number of recorded changes past which a token stops being resolved at all.

  See the moduledoc for why the ceiling exists; it is exposed so that the API
  can spell out what happens to the amounts of a token that crosses it.
  """
  @spec max_changes_per_token() :: pos_integer()
  def max_changes_per_token, do: @max_changes_per_token

  @doc """
  Returns one page of the multiplier history of a single token, newest first,
  each row carrying the timestamp of the block that announced it.

  Unlike `for_tokens/2` this is a plain listing: the cap that stops a token from
  being *resolved* does not apply, since nothing here is loaded per amount, and
  the whole history remains visible however long it grows.

  Changes that are announced but not yet in force are part of the answer — the
  schedule is exactly what makes this history worth showing.

  `:paging_options` pages with the `{block_number, log_index}` of the last row
  of the previous page.
  """
  @spec paginated_for_token(Hash.Address.t(), keyword()) :: [page_entry()]
  def paginated_for_token(token_contract_address_hash, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    token_contract_address_hash
    |> consensus_changes()
    |> page_changes(paging_options)
    |> order_by([change], desc: change.block_number, desc: change.log_index)
    |> limit(^paging_options.page_size)
    |> select([change, block], %{
      block_number: change.block_number,
      block_hash: change.block_hash,
      timestamp: block.timestamp,
      transaction_hash: change.transaction_hash,
      log_index: change.log_index,
      old_multiplier: change.old_multiplier,
      new_multiplier: change.new_multiplier,
      effective_at: change.effective_at
    })
    |> Chain.select_repo(options).all()
  end

  @doc """
  Counts the multiplier changes of a token that `paginated_for_token/2` lists.

  Counted on request rather than kept in a cached counter: the rows sit behind
  the leading column of the primary key and a token has at most a handful of
  them, `@max_changes_per_token` being the hard ceiling.
  """
  @spec count_for_token(Hash.Address.t(), keyword()) :: non_neg_integer()
  def count_for_token(token_contract_address_hash, options \\ []) do
    token_contract_address_hash
    |> consensus_changes()
    |> select([change], count(change.log_index))
    |> Chain.select_repo(options).one()
  end

  # Rows are left in place when the block that carried the log is reorged out,
  # so consensus is what separates what happened from what was rolled back.
  defp consensus_changes(token_contract_address_hash) do
    __MODULE__
    |> join(:inner, [change], block in assoc(change, :block))
    |> where(
      [change, block],
      change.token_contract_address_hash == ^token_contract_address_hash and block.consensus == true
    )
  end

  defp page_changes(query, %PagingOptions{key: nil}), do: query

  defp page_changes(query, %PagingOptions{key: {block_number, log_index}}) do
    where(
      query,
      [change],
      fragment("(?, ?) < (?, ?)", change.block_number, change.log_index, ^block_number, ^log_index)
    )
  end

  defp page_changes(query, _paging_options), do: query

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
  def at(changes, block_number, log_index, timestamp) do
    resolve(changes, &announced_by?(&1, block_number, log_index), timestamp)
  end

  @doc """
  Returns the multiplier that was in force at the end of the given transaction,
  or `nil` when it cannot be told.

  A balance belongs to the whole transaction rather than to a single log of it,
  so a change the transaction itself announced counts even when it was announced
  after the last log this is resolved from. `log_index` is the position of that
  last known log — the transfers the balances were derived from — and it is what
  places the transaction among the changes of its own block; the hash then
  closes the gap between that log and the end of the transaction, since a change
  announced by this very transaction carries it.

  Changes recorded before the hash was stored fall back to `log_index` alone,
  which is what `at/4` would have answered.
  """
  @spec at_end_of_transaction([t()], Transaction.t(), non_neg_integer()) :: Decimal.t() | nil
  def at_end_of_transaction(changes, %Transaction{} = transaction, log_index) do
    resolve(changes, &announced_by_end_of?(&1, transaction, log_index), timestamp_of(transaction))
  end

  defp resolve([], _announced?, _timestamp), do: nil

  # without knowing when the amount happened there is no way to tell whether a
  # scheduled change had already matured, and a guess would be silently wrong
  defp resolve(_changes, _announced?, nil), do: nil

  defp resolve(changes, announced?, timestamp) do
    case Enum.take_while(changes, announced?) do
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

  defp timestamp_of(%Transaction{block_timestamp: timestamp}) when not is_nil(timestamp), do: timestamp

  defp timestamp_of(%Transaction{block: %Block{timestamp: timestamp}}), do: timestamp

  defp timestamp_of(_token_transfer), do: nil

  defp announced_by?(change, block_number, log_index) do
    {change.block_number, change.log_index} <= {block_number, log_index}
  end

  defp announced_by_end_of?(change, transaction, log_index) do
    announced_by?(change, transaction.block_number, log_index) or change.transaction_hash == transaction.hash
  end

  defp in_force_at(change, timestamp) do
    if DateTime.compare(timestamp, change.effective_at) == :lt do
      change.old_multiplier
    else
      change.new_multiplier
    end
  end
end
