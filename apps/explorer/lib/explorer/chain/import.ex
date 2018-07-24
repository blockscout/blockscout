defmodule Explorer.Chain.Import do
  @moduledoc """
  Bulk importing of data into `Explorer.Repo`
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Address, Balance, Block, Hash, InternalTransaction, Log, Transaction, Wei}
  alias Explorer.Repo

  @typep addresses_option :: {:addresses, [params_option | timeout_option | with_option]}
  @typep balances_option :: {:balances, [params_option | timeout_option]}
  @typep blocks_option :: {:blocks, [params_option | timeout_option]}
  @typep broadcast_option :: {:broadcast, Boolean}
  @typep internal_transactions_option :: {:internal_transactions, [params_option | timeout_option]}
  @typep logs_option :: {:logs, [params_option | timeout_option]}
  @typep on_conflict_option :: {:on_conflict, :nothing | :replace_all}
  @typep params_option :: {:params, [map()]}
  @typep receipts_option :: {:receipts, [params_option | timeout_option]}
  @typep timeout_option :: {:timeout, timeout}
  @typep timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}
  @typep timestamps_option :: {:timestamps, timestamps}
  @typep transactions_option :: {:transactions, [on_conflict_option | params_option | timeout_option]}
  @typep with_option :: {:with, changeset_function_name :: atom}

  @type all_options :: [
          addresses_option
          | balances_option
          | blocks_option
          | broadcast_option
          | internal_transactions_option
          | logs_option
          | receipts_option
          | timeout_option
          | transactions_option
        ]
  @type all_result ::
          {:ok,
           %{
             optional(:addresses) => [Address.t()],
             optional(:balances) => [
               %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
             ],
             optional(:blocks) => [Block.t()],
             optional(:internal_transactions) => [
               %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
             ],
             optional(:logs) => [Log.t()],
             optional(:receipts) => [Hash.Full.t()],
             optional(:transactions) => [Hash.Full.t()]
           }}
          | {:error, [Changeset.t()]}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}

  @type internal_transactions_options :: [
          addresses_option
          | internal_transactions_option
          | timeout_option
          | {:transactions, [{:hashes, [String.t()]} | timeout_option]}
        ]
  @type internal_transactions_result ::
          {:ok,
           %{
             optional(:addresses) => [Hash.Address.t()],
             optional(:internal_transactions) => [
               %{required(:index) => non_neg_integer(), required(:transaction_hash) => Hash.Full.t()}
             ]
           }}
          | {:error, [Changeset.t()]}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}

  # timeouts all in milliseconds

  @transaction_timeout 120_000

  @insert_addresses_timeout 60_000
  @insert_balances_timeout 60_000
  @insert_blocks_timeout 60_000
  @insert_internal_transactions_timeout 60_000
  @insert_logs_timeout 60_000
  @insert_transactions_timeout 60_000

  @update_transactions_timeout 60_000

  @doc """
  Bulk insert all data stored in the `Explorer`.

  The import returns the unique key(s) for each type of record inserted.

  | Key                      | Value Type                                                                                      | Value Description                                                                             |
  |--------------------------|-------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
  | `:addresses`             | `[Explorer.Chain.Address.t()]`                                                                  | List of `t:Explorer.Chain.Address.t/0`s                                                       |
  | `:balances`              | `[%{address_hash: Explorer.Chain.Hash.t(), block_number: Explorer.Chain.Block.block_number()}]` | List of `t:Explorer.Chain.Address.t/0`s                                                       |
  | `:blocks`                | `[Explorer.Chain.Block.t()]`                                                                    | List of `t:Explorer.Chain.Block.t/0`s                                                         |
  | `:internal_transactions` | `[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]`                      | List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash` |
  | `:logs`                  | `[Explorer.Chain.Log.t()]`                                                                      | List of `t:Explorer.Chain.Log.t/0`s                                                           |
  | `:transactions`          | `[Explorer.Chain.Hash.t()]`                                                                     | List of `t:Explorer.Chain.Transaction.t/0` `hash`                                             |

  The params for each key are validated using the corresponding `Ecto.Schema` module's `changeset/2` function.  If there
  are errors, they are returned in `Ecto.Changeset.t`s, so that the original, invalid value can be reconstructed for any
  error messages.

  Because there are multiple processes potentially writing to the same tables at the same time,
  `c:Ecto.Repo.insert_all/2`'s
  [`:conflict_target` and `:on_conflict` options](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3-options) are
  used to perform [upserts](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3-upserts) on all tables, so that
  a pre-existing unique key will not trigger a failure, but instead replace or otherwise update the row.

  ## Data Notifications

  On successful inserts, processes interested in certain domains of data will be notified
  that new data has been inserted. See `Explorer.Chain.subscribe_to_events/1` for more information.

  ## Options

    * `:addresses`
      * `:params` - `list` of params for `Explorer.Chain.Address.changeset/2`.
      * `:timeout` - the timeout for inserting all addresses.  Defaults to `#{@insert_addresses_timeout}` milliseconds.
    * `:balances`
      * `:params` - `list` of params for `Explorer.Chain.Balance.changeset/2`.
      * `:timeout` - the timeout for inserting all balances.  Defaults to `#{@insert_balances_timeout}` milliseconds.
    * `:blocks`
      * `:params` - `list` of params for `Explorer.Chain.Block.changeset/2`.
      * `:timeout` - the timeout for inserting all blocks. Defaults to `#{@insert_blocks_timeout}` milliseconds.
    * `:broacast` - Boolean flag indicating whether or not to broadcast the event.
    * `:internal_transactions`
      * `:params` - `list` of params for `Explorer.Chain.InternalTransaction.changeset/2`.
      * `:timeout` - the timeout for inserting all internal transactions. Defaults to
        `#{@insert_internal_transactions_timeout}` milliseconds.
    * `:logs`
      * `:params` - `list` of params for `Explorer.Chain.Log.changeset/2`.
      * `:timeout` - the timeout for inserting all logs. Defaults to `#{@insert_logs_timeout}` milliseconds.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
    * `:transactions`
      * `:on_conflict` - Whether to do `:nothing` or `:replace_all` columns when there is a pre-existing transaction
        with the same hash.

        *NOTE*: Because the repository transaction for a pending `Explorer.Chain.Transaction`s could `COMMIT` after the
        repository transaction for that same transaction being collated into a block, writers, it is recomended to use
        `:nothing` for pending transactions and `:replace_all` for collated transactions, so that collated transactions
        win.
      * `:params` - `list` of params for `Explorer.Chain.Transaction.changeset/2`.
      * `:timeout` - the timeout for inserting all transactions found in the params lists across all
        types. Defaults to `#{@insert_transactions_timeout}` milliseconds.
  """
  @spec all(all_options()) :: all_result()
  def all(options) when is_list(options) do
    broadcast =
      case Keyword.fetch(options, :broadcast) do
        {:ok, broadcast} -> broadcast
        :error -> false
      end

    changes_list_arguments_list = import_options_to_changes_list_arguments_list(options)

    with {:ok, ecto_schema_module_to_changes_list} <-
           changes_list_arguments_list_to_ecto_schema_module_to_changes_list(changes_list_arguments_list),
         {:ok, data} <- insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list, options) do
      if broadcast, do: broadcast_events(data)
      {:ok, data}
    end
  end

  @doc """
  Bulk insert internal transactions for a list of transactions.

  ## Options

    * `:addresses`
      * `:params` - `list` of params for `Explorer.Chain.Address.changeset/2`.
      * `:timeout` - the timeout for inserting all addresses.  Defaults to `#{@insert_addresses_timeout}` milliseconds.
    * `:internal_transactions`
      * `:params` - `list` of params for `Explorer.Chain.InternalTransaction.changeset/2`.
      * `:timeout` - the timeout for inserting all internal transactions. Defaults to
        `#{@insert_internal_transactions_timeout}` milliseconds.
    * `:transactions`
      * `:hashes` - `list` of `t:Explorer.Chain.Transaction.t/0` `hash`es that should have their
          `internal_transactions_indexed_at` updated.
      * `:timeout` - the timeout for updating transactions with `:hashes`.  Defaults to
        `#{@update_transactions_timeout}` milliseconds.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
  """
  @spec internal_transactions(internal_transactions_options()) :: internal_transactions_result
  def internal_transactions(options) when is_list(options) do
    {transactions_options, import_options} = Keyword.pop(options, :transactions)
    changes_list_options_list = import_options_to_changes_list_arguments_list(import_options)

    with {:ok, ecto_schema_module_to_changes_list} <-
           changes_list_arguments_list_to_ecto_schema_module_to_changes_list(changes_list_options_list) do
      timestamps = timestamps()

      ecto_schema_module_to_changes_list
      |> ecto_schema_module_to_changes_list_to_multi(Keyword.put(options, :timestamps, timestamps))
      |> Multi.run(:transactions, fn _ ->
        transaction_hashes = Keyword.get(transactions_options, :hashes)
        transactions_count = length(transaction_hashes)

        query =
          from(
            t in Transaction,
            where: t.hash in ^transaction_hashes,
            update: [set: [internal_transactions_indexed_at: ^timestamps.updated_at]]
          )

        {^transactions_count, result} = Repo.update_all(query, [])

        {:ok, result}
      end)
      |> import_transaction(options)
    end
  end

  defp broadcast_events(data) do
    for {event_type, event_data} <- data, event_type in ~w(addresses balances blocks logs transactions)a do
      broadcast_event_data(event_type, event_data)
    end
  end

  defp broadcast_event_data(event_type, event_data) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:chain_event, event_type, event_data})
      end
    end)
  end

  defp changes_list_arguments_list_to_ecto_schema_module_to_changes_list(changes_list_arguments_list) do
    changes_list_arguments_list
    |> Stream.map(fn [params_list, options] ->
      ecto_schema_module = Keyword.fetch!(options, :for)
      {ecto_schema_module, changes_list(params_list, options)}
    end)
    |> Enum.reduce({:ok, %{}}, fn
      {ecto_schema_module, {:ok, changes_list}}, {:ok, ecto_schema_module_to_changes_list} ->
        {:ok, Map.put(ecto_schema_module_to_changes_list, ecto_schema_module, changes_list)}

      {_, {:ok, _}}, {:error, _} = error ->
        error

      {_, {:error, _} = error}, {:ok, _} ->
        error

      {_, {:error, changesets}}, {:error, acc_changesets} ->
        {:error, acc_changesets ++ changesets}
    end)
  end

  @spec changes_list(params :: [map], [{:for, module} | {:with, atom}]) :: {:ok, [map]} | {:error, [Changeset.t()]}
  defp changes_list(params, options) when is_list(options) do
    ecto_schema_module = Keyword.fetch!(options, :for)
    changeset_function_name = Keyword.get(options, :with, :changeset)
    struct = ecto_schema_module.__struct__()

    {status, acc} =
      params
      |> Stream.map(&apply(ecto_schema_module, changeset_function_name, [struct, &1]))
      |> Enum.reduce({:ok, []}, fn
        changeset = %Changeset{valid?: false}, {:ok, _} ->
          {:error, [changeset]}

        changeset = %Changeset{valid?: false}, {:error, acc_changesets} ->
          {:error, [changeset | acc_changesets]}

        %Changeset{changes: changes, valid?: true}, {:ok, acc_changes} ->
          {:ok, [changes | acc_changes]}

        %Changeset{valid?: true}, {:error, _} = error ->
          error
      end)

    {status, Enum.reverse(acc)}
  end

  @import_option_key_to_ecto_schema_module %{
    addresses: Address,
    balances: Balance,
    blocks: Block,
    internal_transactions: InternalTransaction,
    logs: Log,
    transactions: Transaction
  }

  defp ecto_schema_module_to_changes_list_to_multi(ecto_schema_module_to_changes_list, options) when is_list(options) do
    timestamps = timestamps()
    full_options = Keyword.put(options, :timestamps, timestamps)

    Multi.new()
    |> run_addresses(ecto_schema_module_to_changes_list, full_options)
    |> run_balances(ecto_schema_module_to_changes_list, full_options)
    |> run_blocks(ecto_schema_module_to_changes_list, full_options)
    |> run_transactions(ecto_schema_module_to_changes_list, full_options)
    |> run_internal_transactions(ecto_schema_module_to_changes_list, full_options)
    |> run_logs(ecto_schema_module_to_changes_list, full_options)
  end

  defp run_addresses(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Address => addresses_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :addresses, fn _ ->
          insert_addresses(
            addresses_changes,
            timeout: options[:addresses][:timeout] || @insert_addresses_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  defp run_balances(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Balance => balances_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :balances, fn _ ->
          insert_balances(
            balances_changes,
            timeout: options[:balances][:timeout] || @insert_balances_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  defp run_blocks(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Block => blocks_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :blocks, fn _ ->
          insert_blocks(
            blocks_changes,
            timeout: options[:blocks][:timeout] || @insert_blocks_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  defp run_transactions(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Transaction => transactions_changes} ->
        # check required options as early as possible
        transactions_options = Keyword.fetch!(options, :transactions)
        on_conflict = Keyword.fetch!(transactions_options, :on_conflict)
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :transactions, fn _ ->
          insert_transactions(
            transactions_changes,
            on_conflict: on_conflict,
            timeout: transactions_options[:timeout] || @insert_transactions_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  defp run_internal_transactions(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{InternalTransaction => internal_transactions_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :internal_transactions, fn _ ->
          insert_internal_transactions(
            internal_transactions_changes,
            timeout: options[:internal_transactions][:timeout] || @insert_internal_transactions_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  defp run_logs(multi, ecto_schema_module_to_changes_list, options)
       when is_map(ecto_schema_module_to_changes_list) and is_list(options) do
    case ecto_schema_module_to_changes_list do
      %{Log => logs_changes} ->
        timestamps = Keyword.fetch!(options, :timestamps)

        Multi.run(multi, :logs, fn _ ->
          insert_logs(
            logs_changes,
            timeout: options[:logs][:timeout] || @insert_logs_timeout,
            timestamps: timestamps
          )
        end)

      _ ->
        multi
    end
  end

  @spec insert_addresses([%{hash: Hash.Address.t()}], [timeout_option | timestamps_option | with_option]) ::
          {:ok, [Hash.Address.t()]}
  defp insert_addresses(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = sort_address_changes_list(changes_list)

    insert_changes_list(
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict:
        from(
          address in Address,
          update: [
            set: [
              contract_code: fragment("COALESCE(?, EXCLUDED.contract_code)", address.contract_code),
              # ARGMAX on two columns
              fetched_balance:
                fragment(
                  """
                  CASE WHEN EXCLUDED.fetched_balance_block_number IS NOT NULL AND
                            (? IS NULL OR
                             EXCLUDED.fetched_balance_block_number >= ?) THEN
                              EXCLUDED.fetched_balance
                       ELSE ?
                  END
                  """,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number,
                  address.fetched_balance
                ),
              # MAX on two columns
              fetched_balance_block_number:
                fragment(
                  """
                  CASE WHEN EXCLUDED.fetched_balance_block_number IS NOT NULL AND
                            (? IS NULL OR
                             EXCLUDED.fetched_balance_block_number >= ?) THEN
                              EXCLUDED.fetched_balance_block_number
                       ELSE ?
                  END
                  """,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number,
                  address.fetched_balance_block_number
                )
            ]
          ]
        ),
      for: Address,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp sort_address_changes_list(changes_list) do
    Enum.sort_by(changes_list, & &1.hash)
  end

  @spec insert_balances(
          [
            %{
              required(:address_hash) => Hash.Address.t(),
              required(:block_number) => Block.block_number(),
              required(:value) => Wei.t()
            }
          ],
          [timeout_option]
        ) ::
          {:ok, [%{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}]}
          | {:error, [Changeset.t()]}
  defp insert_balances(changes_list, named_arguments) when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.block_number})

    {:ok, _} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: [:address_hash, :block_number],
        on_conflict:
          from(
            balance in Balance,
            update: [
              set: [
                inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", balance.inserted_at),
                updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", balance.updated_at),
                value:
                  fragment(
                    """
                    CASE WHEN EXCLUDED.updated_at > ? THEN EXCLUDED.value
                         ELSE  ?
                    END
                    """,
                    balance.updated_at,
                    balance.value
                  )
              ]
            ]
          ),
        for: Balance,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, Enum.map(ordered_changes_list, &Map.take(&1, ~w(address_hash block_number)a))}
  end

  @spec insert_blocks([map()], [timeout_option | timestamps_option]) :: {:ok, [Block.t()]} | {:error, [Changeset.t()]}
  defp insert_blocks(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.number, &1.hash})

    {:ok, blocks} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :number,
        on_conflict: :replace_all,
        for: Block,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, blocks}
  end

  @spec insert_internal_transactions([map], [timeout_option | timestamps_option]) ::
          {:ok, [%{index: non_neg_integer, transaction_hash: Hash.t()}]}
          | {:error, [Changeset.t()]}
  defp insert_internal_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, internal_transactions} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        for: InternalTransaction,
        on_conflict: :replace_all,
        returning: [:index, :transaction_hash],
        timestamps: timestamps
      )

    {:ok,
     for(
       internal_transaction <- internal_transactions,
       do: Map.take(internal_transaction, [:index, :transaction_hash])
     )}
  end

  @spec insert_logs([map()], [timeout_option | timestamps_option]) ::
          {:ok, [Log.t()]}
          | {:error, [Changeset.t()]}
  defp insert_logs(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, _} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        on_conflict: :replace_all,
        for: Log,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  @spec insert_transactions([map()], [on_conflict_option | timeout_option | timestamps_option]) ::
          {:ok, [Hash.t()]} | {:error, [Changeset.t()]}
  defp insert_transactions(changes_list, named_arguments)
       when is_list(changes_list) and is_list(named_arguments) do
    timestamps = Keyword.fetch!(named_arguments, :timestamps)
    timeout = Keyword.fetch!(named_arguments, :timeout)
    on_conflict = Keyword.fetch!(named_arguments, :on_conflict)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    {:ok, transactions} =
      insert_changes_list(
        ordered_changes_list,
        conflict_target: :hash,
        on_conflict: on_conflict,
        for: Transaction,
        returning: [:hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(transaction <- transactions, do: transaction.hash)}
  end

  defp insert_changes_list(changes_list, options) when is_list(changes_list) do
    ecto_schema_module = Keyword.fetch!(options, :for)

    timestamped_changes_list = timestamp_changes_list(changes_list, Keyword.fetch!(options, :timestamps))

    {_, inserted} =
      Repo.safe_insert_all(
        ecto_schema_module,
        timestamped_changes_list,
        Keyword.delete(options, :for)
      )

    {:ok, inserted}
  end

  defp timestamp_changes_list(changes_list, timestamps) when is_list(changes_list) do
    Enum.map(changes_list, &timestamp_params(&1, timestamps))
  end

  defp timestamp_params(changes, timestamps) when is_map(changes) do
    Map.merge(changes, timestamps)
  end

  defp import_options_to_changes_list_arguments_list(options) do
    Enum.flat_map(@import_option_key_to_ecto_schema_module, fn {option_key, ecto_schema_module} ->
      case Keyword.fetch(options, option_key) do
        {:ok, option_value} when is_list(option_value) ->
          [
            [
              Keyword.fetch!(option_value, :params),
              [for: ecto_schema_module, with: Keyword.get(option_value, :with, :changeset)]
            ]
          ]

        :error ->
          []
      end
    end)
  end

  defp import_transaction(multi, options) when is_list(options) do
    Repo.transaction(multi, timeout: Keyword.get(options, :timeout, @transaction_timeout))
  end

  defp insert_ecto_schema_module_to_changes_list(ecto_schema_module_to_changes_list, options) do
    timestamps = timestamps()

    ecto_schema_module_to_changes_list
    |> ecto_schema_module_to_changes_list_to_multi(Keyword.put(options, :timestamps, timestamps))
    |> import_transaction(options)
  end

  @spec timestamps() :: timestamps
  defp timestamps do
    now = DateTime.utc_now()
    %{inserted_at: now, updated_at: now}
  end
end
