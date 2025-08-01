defmodule Explorer.Chain.Optimism.Withdrawal do
  @moduledoc "Models Optimism withdrawal."

  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Application.Constants
  alias Explorer.Chain.{Block, Hash, Transaction}
  alias Explorer.Chain.Cache.OptimismFinalizationPeriod
  alias Explorer.Chain.Optimism.{DisputeGame, OutputRoot, WithdrawalEvent}
  alias Explorer.{Helper, PagingOptions, Repo}

  @game_status_defender_wins 2

  @withdrawal_status_waiting_for_state_root "Waiting for state root"
  @withdrawal_status_ready_to_prove "Ready to prove"
  @withdrawal_status_waiting_to_resolve "Waiting a game to resolve"
  @withdrawal_status_in_challenge "In challenge period"
  @withdrawal_status_ready_for_relay "Ready for relay"
  @withdrawal_status_proven "Proven"
  @withdrawal_status_relayed "Relayed"

  @dispute_game_finality_delay_seconds "optimism_dispute_game_finality_delay_seconds"
  @proof_maturity_delay_seconds "optimism_proof_maturity_delay_seconds"

  @required_attrs ~w(msg_nonce hash l2_transaction_hash l2_block_number)a
  @game_fields ~w(created_at resolved_at status)a

  @typedoc """
    * `msg_nonce` - A nonce of the withdrawal message.
    * `hash` - A withdrawal hash.
    * `l2_transaction_hash` - An L2 transaction hash which initiated the withdrawal.
    * `l2_block_number` - A block number of the L2 transaction.
  """
  @primary_key false
  typed_schema "op_withdrawals" do
    field(:msg_nonce, :decimal, primary_key: true)
    field(:hash, Hash.Full)
    field(:l2_transaction_hash, Hash.Full)
    field(:l2_block_number, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = withdrawals, attrs \\ %{}) do
    withdrawals
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
  Lists `t:Explorer.Chain.Optimism.Withdrawal.t/0`'s' in descending order based on message nonce.

  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(w in __MODULE__,
            order_by: [desc: w.msg_nonce],
            left_join: l2_transaction in Transaction,
            on: w.l2_transaction_hash == l2_transaction.hash,
            left_join: l2_block in Block,
            on: w.l2_block_number == l2_block.number,
            left_join: we in WithdrawalEvent,
            on: we.withdrawal_hash == w.hash and we.l1_event_type == :WithdrawalFinalized,
            select: %{
              msg_nonce: w.msg_nonce,
              hash: w.hash,
              l2_block_number: w.l2_block_number,
              l2_timestamp: l2_block.timestamp,
              l2_transaction_hash: w.l2_transaction_hash,
              l1_transaction_hash: we.l1_transaction_hash,
              from: l2_transaction.from_address_hash
            }
          )

        base_query
        |> page_optimism_withdrawals(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all(timeout: :infinity)
    end
  end

  defp page_optimism_withdrawals(query, %PagingOptions{key: nil}), do: query

  defp page_optimism_withdrawals(query, %PagingOptions{key: {nonce}}) do
    from(w in query, where: w.msg_nonce < ^nonce)
  end

  @doc """
    Forms a query to find the last Withdrawal's L2 block number and transaction hash.
    Used by the `Indexer.Fetcher.Optimism.Withdrawal` module.

    ## Returns
    - A query which can be used by the `Repo.one` function.
  """
  @spec last_withdrawal_l2_block_number_query() :: Ecto.Queryable.t()
  def last_withdrawal_l2_block_number_query do
    from(w in __MODULE__,
      select: {w.l2_block_number, w.l2_transaction_hash},
      order_by: [desc: w.msg_nonce],
      limit: 1
    )
  end

  @doc """
    Forms a query to remove all Withdrawals related to the specified L2 block number.
    Used by the `Indexer.Fetcher.Optimism.Withdrawal` module.

    ## Parameters
    - `l2_block_number`: The L2 block number for which the Withdrawals should be removed
                         from the `op_withdrawals` database table.

    ## Returns
    - A query which can be used by the `delete_all` function.
  """
  @spec remove_withdrawals_query(non_neg_integer()) :: Ecto.Queryable.t()
  def remove_withdrawals_query(l2_block_number) do
    from(w in __MODULE__, where: w.l2_block_number == ^l2_block_number)
  end

  @doc """
    Gets withdrawal statuses for Optimism Withdrawal transaction.
    For each withdrawal associated with this transaction,
    returns the status and the corresponding L1 transaction hash if the status is `Relayed`.
  """
  @spec transaction_statuses(Hash.t()) :: [{non_neg_integer(), String.t(), Hash.t() | nil}]
  def transaction_statuses(l2_transaction_hash) do
    query =
      from(w in __MODULE__,
        where: w.l2_transaction_hash == ^l2_transaction_hash,
        left_join: l2_block in Block,
        on: w.l2_block_number == l2_block.number and l2_block.consensus == true,
        left_join: we in WithdrawalEvent,
        on: we.withdrawal_hash == w.hash and we.l1_event_type == :WithdrawalFinalized,
        select: %{
          hash: w.hash,
          l2_block_number: w.l2_block_number,
          l1_transaction_hash: we.l1_transaction_hash,
          msg_nonce: w.msg_nonce
        }
      )

    query
    |> Repo.replica().all(timeout: :infinity)
    |> Enum.map(fn w ->
      msg_nonce =
        Bitwise.band(
          Decimal.to_integer(w.msg_nonce),
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
        )

      {status, _} = status(w)
      {msg_nonce, status, w.l1_transaction_hash}
    end)
  end

  @doc """
    Gets Optimism Withdrawal status and unlock datetime (only for `In challenge period`).

    Since OP Fault Proofs implementation assumes having more than one WithdrawalProven events for
    the same withdrawal, the function analyzes all the WithdrawalProven events and determines
    the current withdrawal status for each of them. The first success status is taken and returned
    as the final one.

    ## Parameters
    - `w`: A map with the withdrawal info.
    - `respected_games`: A list of games returned by the `respected_games()` function.
                         Used to avoid duplicated SQL requests when the `status` function
                         is called in a loop. If `nil`, the `respected_games()` function
                         is called internally.

    ## Returns
    - `{status, datetime}` tuple where the `status` is the current withdrawal status,
                           `datetime` is the point of time when the challenge period ends.
                           (only for `In challenge period` status).
  """
  @spec status(map(), list() | nil) :: {String.t(), DateTime.t() | nil}
  def status(w, respected_games \\ nil)

  def status(w, respected_games) when is_nil(w.l1_transaction_hash) do
    proven_events = proven_events_by_hash(w.hash)

    respected_games =
      if is_nil(respected_games) do
        respected_games()
      else
        respected_games
      end

    if proven_events == [] do
      cond do
        appropriate_games_found(w.l2_block_number, respected_games) ->
          {@withdrawal_status_ready_to_prove, nil}

        appropriate_root_found(w.l2_block_number) ->
          {@withdrawal_status_ready_to_prove, nil}

        true ->
          {@withdrawal_status_waiting_for_state_root, nil}
      end
    else
      handle_proven_status(proven_events, respected_games)
    end
  end

  def status(_w, _respected_games) do
    {@withdrawal_status_relayed, nil}
  end

  @doc """
    Returns the list of games which type is equal to the current respected game type
    received from OptimismPortal contract.
  """
  @spec respected_games() :: list()
  def respected_games do
    case Helper.parse_integer(Constants.get_constant_value("optimism_respected_game_type")) do
      nil ->
        []

      game_type ->
        query =
          from(g in DisputeGame,
            where: g.game_type == ^game_type,
            order_by: [desc: g.index],
            limit: 100
          )

        Repo.all(query, timeout: :infinity)
    end
  end

  @doc """
    Returns a name of the dispute_game_finality_delay_seconds constant.
  """
  @spec dispute_game_finality_delay_seconds_constant() :: binary()
  def dispute_game_finality_delay_seconds_constant do
    @dispute_game_finality_delay_seconds
  end

  @doc """
    Returns a name of the proof_maturity_delay_seconds constant.
  """
  @spec proof_maturity_delay_seconds_constant() :: binary()
  def proof_maturity_delay_seconds_constant do
    @proof_maturity_delay_seconds
  end

  defp appropriate_games_found(withdrawal_l2_block_number, respected_games) do
    respected_games
    |> Enum.any?(fn game ->
      l2_block_number = DisputeGame.l2_block_number_from_extra_data(game.extra_data)
      withdrawal_l2_block_number <= l2_block_number
    end)
  end

  defp appropriate_root_found(withdrawal_l2_block_number) do
    last_root_l2_block_number =
      Repo.replica().one(
        from(root in OutputRoot,
          select: root.l2_block_number,
          order_by: [desc: root.l2_output_index],
          limit: 1
        )
      ) || 0

    withdrawal_l2_block_number <= last_root_l2_block_number
  end

  # Fetches dispute game info from DB by game's contract address hash or game's unique index.
  #
  # ## Parameters
  # - `game_address_hash`: Game's contract address hash. Must be `nil` if unknown.
  # - `game_index`: Game unique index. Must be `nil` if unknown.
  #
  # ## Returns
  # - A map with necessary info about the dispute game.
  # - `nil` if the dispute game not found in DB or both input parameters are `nil`.
  @spec game_by_address_hash_or_index(Hash.t() | nil, non_neg_integer() | nil) ::
          %{:created_at => DateTime.t(), :resolved_at => DateTime.t(), :status => non_neg_integer()} | nil
  defp game_by_address_hash_or_index(nil, nil), do: nil

  defp game_by_address_hash_or_index(game_address_hash, nil) do
    Repo.replica().one(
      from(
        g in DisputeGame,
        select: map(g, ^@game_fields),
        where: g.address_hash == ^game_address_hash,
        limit: 1
      )
    )
  end

  defp game_by_address_hash_or_index(_game_address_hash, game_index) when not is_nil(game_index) do
    Repo.replica().one(
      from(
        g in DisputeGame,
        select: map(g, ^@game_fields),
        where: g.index == ^game_index
      )
    )
  end

  # Determines the current withdrawal status by the list of the bound WithdrawalProven events.
  #
  # ## Parameters
  # - `proven_events`: A list of WithdrawalProven events. Each item is `{l1_timestamp, game_address_hash, game_index}` tuple.
  # - `respected_games`: A list of games returned by the `respected_games()` function.
  #
  # ## Returns
  # - `{status, datetime}` tuple where the `status` is the current withdrawal status,
  #                        `datetime` is the point of time when the challenge period ends.
  #                        (only for `In challenge period` status).
  @spec handle_proven_status(list(), list()) :: {String.t(), DateTime.t() | nil}
  defp handle_proven_status(proven_events, respected_games) do
    statuses =
      proven_events
      |> Enum.reduce_while([], fn {l1_timestamp, game_address_hash, game_index}, acc ->
        game = game_by_address_hash_or_index(game_address_hash, game_index)

        # credo:disable-for-lines:16 Credo.Check.Refactor.PipeChainStart
        cond do
          is_nil(game) and not Enum.empty?(respected_games) ->
            # here we cannot exactly determine the status `Waiting a game to resolve` or
            # `Ready for relay` or `In challenge period`
            # as we don't know the game index and address. In this case we display the `Proven` status
            {@withdrawal_status_proven, nil}

          is_nil(game) or DateTime.compare(l1_timestamp, game.created_at) == :lt ->
            # the old status determining approach
            pre_fault_proofs_status(l1_timestamp)

          true ->
            # the new status determining approach
            post_fault_proofs_status(l1_timestamp, game)
        end
        |> case do
          {@withdrawal_status_ready_for_relay, _} = status -> {:halt, [status]}
          status -> {:cont, [status | acc]}
        end
      end)

    status_priority =
      %{}
      |> Map.put(@withdrawal_status_in_challenge, 30)
      |> Map.put(@withdrawal_status_waiting_to_resolve, 20)
      |> Map.put(@withdrawal_status_proven, 10)

    statuses
    |> Enum.sort_by(
      fn {s, timestamp} ->
        {status_priority[s], if(not is_nil(timestamp), do: -DateTime.to_unix(timestamp))}
      end,
      :desc
    )
    |> List.first()
  end

  # Gets the list of WithdrawalProven events from the `op_withdrawal_events` database table
  # bound with the given withdrawal hash. The returned events are sorted by `l1_block_number`
  # in ascending order.
  #
  # ## Parameters
  # - `withdrawal_hash`: The withdrawal hash for which the function should return the events.
  #
  # ## Returns
  # - A list of `{l1_timestamp, game_address_hash, game_index}` tuples where `l1_timestamp` is the L1 block timestamp
  #   when the event appeared, `game_address_hash` is the bound dispute game contract address hash (can be `nil`),
  #   `game_index` is the bound dispute game index (can be `nil`).
  @spec proven_events_by_hash(Hash.t()) :: [{DateTime.t(), Hash.t() | nil, non_neg_integer() | nil}]
  defp proven_events_by_hash(withdrawal_hash) do
    Repo.replica().all(
      from(
        we in WithdrawalEvent,
        select: {we.l1_timestamp, we.game_address_hash, we.game_index},
        where: we.withdrawal_hash == ^withdrawal_hash and we.l1_event_type == :WithdrawalProven,
        order_by: [asc: we.l1_block_number]
      ),
      timeout: :infinity
    )
  end

  defp pre_fault_proofs_status(l1_timestamp) do
    challenge_period =
      case OptimismFinalizationPeriod.get_period() do
        nil -> 604_800
        period -> period
      end

    if DateTime.compare(l1_timestamp, DateTime.add(DateTime.utc_now(), -challenge_period)) == :lt do
      {@withdrawal_status_ready_for_relay, nil}
    else
      {@withdrawal_status_in_challenge, DateTime.add(l1_timestamp, challenge_period)}
    end
  end

  defp post_fault_proofs_status(l1_timestamp, game) do
    if game.status != @game_status_defender_wins do
      # the game status is not DEFENDER_WINS
      {@withdrawal_status_waiting_to_resolve, nil}
    else
      dispute_game_finality_delay_seconds =
        Helper.parse_integer(Constants.get_constant_value(@dispute_game_finality_delay_seconds))

      proof_maturity_delay_seconds = Helper.parse_integer(Constants.get_constant_value(@proof_maturity_delay_seconds))

      false = is_nil(dispute_game_finality_delay_seconds)
      false = is_nil(proof_maturity_delay_seconds)

      finality_delayed = DateTime.add(game.resolved_at, dispute_game_finality_delay_seconds)
      proof_delayed = DateTime.add(l1_timestamp, proof_maturity_delay_seconds)

      now = DateTime.utc_now()

      if DateTime.compare(now, finality_delayed) == :lt or DateTime.compare(now, finality_delayed) == :eq or
           DateTime.compare(now, proof_delayed) == :lt or DateTime.compare(now, proof_delayed) == :eq do
        seconds_left1 = max(DateTime.diff(finality_delayed, now), 0)
        seconds_left2 = max(DateTime.diff(proof_delayed, now), 0)
        seconds_left = max(seconds_left1, seconds_left2)

        {@withdrawal_status_in_challenge, DateTime.add(now, seconds_left)}
      else
        {@withdrawal_status_ready_for_relay, nil}
      end
    end
  end
end
