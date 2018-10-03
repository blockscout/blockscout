defmodule Explorer.Chain.Import do
  @moduledoc """
  Bulk importing of data into `Explorer.Repo`
  """

  alias Ecto.{Changeset, Multi}

  alias Explorer.Chain.{
    Address,
    Address.CoinBalance,
    Address.TokenBalance,
    Block,
    Import,
    InternalTransaction,
    Log,
    Token,
    TokenTransfer,
    Transaction
  }

  alias Explorer.Repo

  @type changeset_function_name :: atom
  @type on_conflict :: :nothing | :replace_all
  @type params :: [map()]
  @type all_options :: %{
          optional(:addresses) => Import.Addresses.options(),
          optional(:address_coin_balances) => Import.Address.CoinBalances.options(),
          optional(:address_token_balances) => Import.Address.TokenBalances.options(),
          optional(:blocks) => Import.Blocks.options(),
          optional(:block_second_degree_relations) => Import.Block.SecondDegreeRelations.options(),
          optional(:broadcast) => boolean,
          optional(:internal_transactions) => Import.InternalTransactions.options(),
          optional(:logs) => Import.Logs.options(),
          optional(:timeout) => timeout,
          optional(:token_transfers) => Import.TokenTransfers.options(),
          optional(:tokens) => Import.Tokens.options(),
          optional(:transactions) => Import.Transactions.options(),
          optional(:transaction_forks) => Import.Transaction.Forks.options()
        }
  @type all_result ::
          {:ok,
           %{
             optional(:addresses) => Import.Addresses.imported(),
             optional(:address_coin_balances) => Import.Address.CoinBalances.imported(),
             optional(:address_token_balances) => Import.Address.TokenBalances.imported(),
             optional(:blocks) => Import.Blocks.imported(),
             optional(:block_second_degree_relations) => Import.Block.SecondDegreeRelations.imported(),
             optional(:internal_transactions) => Import.InternalTransactions.imported(),
             optional(:logs) => Import.Logs.imported(),
             optional(:token_transfers) => Import.TokenTransfers.imported(),
             optional(:tokens) => Import.Tokens.imported(),
             optional(:transactions) => Import.Transactions.imported(),
             optional(:transaction_forks) => Import.Transaction.Forks.imported()
           }}
          | {:error, [Changeset.t()]}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}

  @type timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}

  # milliseconds
  @transaction_timeout 120_000

  @doc """
  Bulk insert all data stored in the `Explorer`.

  The import returns the unique key(s) for each type of record inserted.

  | Key                              | Value Type                                                                                      | Value Description                                                                                    |
  |----------------------------------|-------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
  | `:addresses`                     | `[Explorer.Chain.Address.t()]`                                                                  | List of `t:Explorer.Chain.Address.t/0`s                                                              |
  | `:address_coin_balances`         | `[%{address_hash: Explorer.Chain.Hash.t(), block_number: Explorer.Chain.Block.block_number()}]` | List of  maps of the `t:Explorer.Chain.Address.CoinBalance.t/0` `address_hash` and `block_number`    |
  | `:blocks`                        | `[Explorer.Chain.Block.t()]`                                                                    | List of `t:Explorer.Chain.Block.t/0`s                                                                |
  | `:internal_transactions`         | `[%{index: non_neg_integer(), transaction_hash: Explorer.Chain.Hash.t()}]`                      | List of maps of the `t:Explorer.Chain.InternalTransaction.t/0` `index` and `transaction_hash`        |
  | `:logs`                          | `[Explorer.Chain.Log.t()]`                                                                      | List of `t:Explorer.Chain.Log.t/0`s                                                                  |
  | `:token_transfers`               | `[Explorer.Chain.TokenTransfer.t()]`                                                            | List of `t:Explorer.Chain.TokenTransfer.t/0`s                                                        |
  | `:tokens`                        | `[Explorer.Chain.Token.t()]`                                                                    | List of `t:Explorer.Chain.token.t/0`s                                                                |
  | `:transactions`                  | `[Explorer.Chain.Hash.t()]`                                                                     | List of `t:Explorer.Chain.Transaction.t/0` `hash`                                                    |
  | `:transaction_forks`             | `[%{uncle_hash: Explorer.Chain.Hash.t(), hash: Explorer.Chain.Hash.t()}]`                       | List of maps of the `t:Explorer.Chain.Transaction.Fork.t/0` `uncle_hash` and `hash`                  |
  | `:block_second_degree_relations` | `[%{uncle_hash: Explorer.Chain.Hash.t(), nephew_hash: Explorer.Chain.Hash.t()]`                 | List of maps of the `t:Explorer.Chain.Block.SecondDegreeRelation.t/0` `uncle_hash` and `nephew_hash` |

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
      * `:timeout` - the timeout for inserting all addresses.  Defaults to `#{Import.Addresses.timeout()}` milliseconds.
      * `:with` - the changeset function on `Explorer.Chain.Address` to use validate `:params`.
    * `:address_coin_balances`
      * `:params` - `list` of params for `Explorer.Chain.Address.CoinBalance.changeset/2`.
      * `:timeout` - the timeout for inserting all balances.  Defaults to `#{Import.Address.CoinBalances.timeout()}`
        milliseconds.
    * `:address_token_balances`
      * `:params` - `list` of params for `Explorer.Chain.TokenBalance.changeset/2`
    * `:blocks`
      * `:params` - `list` of params for `Explorer.Chain.Block.changeset/2`.
      * `:timeout` - the timeout for inserting all blocks. Defaults to `#{Import.Blocks.timeout()}` milliseconds.
    * `:block_second_degree_relations`
      * `:params` - `list` of params `for `Explorer.Chain.Block.SecondDegreeRelation.changeset/2`.
      * `:timeout` - the timeout for inserting all uncles found in the params list.  Defaults to
        `#{Import.Block.SecondDegreeRelations.timeout()}` milliseconds.
    * `:broadcast` - Boolean flag indicating whether or not to broadcast the event.
    * `:internal_transactions`
      * `:params` - `list` of params for `Explorer.Chain.InternalTransaction.changeset/2`.
      * `:timeout` - the timeout for inserting all internal transactions. Defaults to
        `#{Import.InternalTransactions.timeout()}` milliseconds.
    * `:logs`
      * `:params` - `list` of params for `Explorer.Chain.Log.changeset/2`.
      * `:timeout` - the timeout for inserting all logs. Defaults to `#{Import.Logs.timeout()}` milliseconds.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
    * `:token_transfers`
      * `:params` - `list` of params for `Explorer.Chain.TokenTransfer.changeset/2`
      * `:timeout` - the timeout for inserting all token transfers. Defaults to `#{Import.TokenTransfers.timeout()}`
        milliseconds.
    * `:tokens`
      * `:on_conflict` - Whether to do `:nothing` or `:replace_all` columns when there is a pre-existing token
        with the same contract address hash.
      * `:params` - `list` of params for `Explorer.Chain.Token.changeset/2`
      * `:timeout` - the timeout for inserting all tokens. Defaults to `#{Import.Tokens.timeout()}` milliseconds.
    * `:transactions`
      * `:on_conflict` - Whether to do `:nothing` or `:replace_all` columns when there is a pre-existing transaction
        with the same hash.

        *NOTE*: Because the repository transaction for a pending `Explorer.Chain.Transaction`s could `COMMIT` after the
        repository transaction for that same transaction being collated into a block, writers, it is recommended to use
        `:nothing` for pending transactions and `:replace_all` for collated transactions, so that collated transactions
        win.
      * `:params` - `list` of params for `Explorer.Chain.Transaction.changeset/2`.
      * `:timeout` - the timeout for inserting all transactions found in the params lists across all
        types. Defaults to `#{Import.Transactions.timeout()}` milliseconds.
      * `:with` - the changeset function on `Explorer.Chain.Transaction` to use validate `:params`.
    * `:transaction_forks`
      * `:params` - `list` of params for `Explorer.Chain.Transaction.Fork.changeset/2`.
      * `:timeout` - the timeout for inserting all transaction forks.  Defaults to
        `#{Import.Transaction.Forks.timeout()}` milliseconds.
    * `:timeout` - the timeout for `Repo.transaction`. Defaults to `#{@transaction_timeout}` milliseconds.

  """
  @spec all(all_options()) :: all_result()
  def all(options) when is_map(options) do
    changes_list_arguments_list = import_options_to_changes_list_arguments_list(options)

    with {:ok, ecto_schema_module_to_changes_list_map} <-
           changes_list_arguments_list_to_ecto_schema_module_to_changes_list_map(changes_list_arguments_list),
         {:ok, data} <- insert_ecto_schema_module_to_changes_list_map(ecto_schema_module_to_changes_list_map, options) do
      if Map.get(options, :broadcast, false), do: broadcast_events(data)
      {:ok, data}
    end
  end

  defp broadcast_events(data) do
    for {event_type, event_data} <- data,
        event_type in ~w(addresses address_coin_balances blocks internal_transactions logs transactions)a do
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

  defp changes_list_arguments_list_to_ecto_schema_module_to_changes_list_map(changes_list_arguments_list) do
    changes_list_arguments_list
    |> Stream.map(fn [params_list, options] ->
      ecto_schema_module = Keyword.fetch!(options, :for)
      {ecto_schema_module, changes_list(params_list, options)}
    end)
    |> Enum.reduce({:ok, %{}}, fn
      {ecto_schema_module, {:ok, changes_list}}, {:ok, ecto_schema_module_to_changes_list_map} ->
        {:ok, Map.put(ecto_schema_module_to_changes_list_map, ecto_schema_module, changes_list)}

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
    address_coin_balances: CoinBalance,
    address_token_balances: TokenBalance,
    blocks: Block,
    block_second_degree_relations: Block.SecondDegreeRelation,
    internal_transactions: InternalTransaction,
    logs: Log,
    token_transfers: TokenTransfer,
    tokens: Token,
    transactions: Transaction,
    transaction_forks: Transaction.Fork
  }

  defp ecto_schema_module_to_changes_list_map_to_multi(ecto_schema_module_to_changes_list_map, options)
       when is_map(options) do
    timestamps = timestamps()
    full_options = Map.put(options, :timestamps, timestamps)

    Multi.new()
    |> Import.Addresses.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Address.CoinBalances.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Blocks.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Block.SecondDegreeRelations.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Transactions.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Transaction.Forks.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.InternalTransactions.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Logs.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Tokens.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.TokenTransfers.run(ecto_schema_module_to_changes_list_map, full_options)
    |> Import.Address.TokenBalances.run(ecto_schema_module_to_changes_list_map, full_options)
  end

  def insert_changes_list(changes_list, options) when is_list(changes_list) do
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
    Enum.flat_map(
      @import_option_key_to_ecto_schema_module,
      &import_options_to_changes_list_arguments_list_flat_mapper(options, &1)
    )
  end

  defp import_options_to_changes_list_arguments_list_flat_mapper(options, {option_key, ecto_schema_module}) do
    case Map.fetch(options, option_key) do
      {:ok, option_value} ->
        import_option_to_changes_list_arguments_list_flat_mapper(option_value, ecto_schema_module)

      :error ->
        []
    end
  end

  defp import_option_to_changes_list_arguments_list_flat_mapper(%{params: params} = option_value, ecto_schema_module) do
    # Use `Enum.empty?` instead of `[_ | _]` as params are allowed to be any collection of maps
    case Enum.empty?(params) do
      false ->
        [
          [
            params,
            [for: ecto_schema_module, with: Map.get(option_value, :with, :changeset)]
          ]
        ]

      # filter out empty params as early as possible, so that later stages don't need to deal with empty params
      # leading to selecting all rows because they produce no where conditions as happened in
      # https://github.com/poanetwork/blockscout/issues/850
      true ->
        []
    end
  end

  defp import_transaction(multi, options) when is_map(options) do
    Repo.transaction(multi, timeout: Map.get(options, :timeout, @transaction_timeout))
  end

  defp insert_ecto_schema_module_to_changes_list_map(ecto_schema_module_to_changes_list_map, options) do
    ecto_schema_module_to_changes_list_map
    |> ecto_schema_module_to_changes_list_map_to_multi(options)
    |> import_transaction(options)
  end

  @spec timestamps() :: timestamps
  defp timestamps do
    now = DateTime.utc_now()
    %{inserted_at: now, updated_at: now}
  end
end
