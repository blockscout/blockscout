defmodule Explorer.Chain.Import do
  @moduledoc """
  Bulk importing of data into `Explorer.Repo`
  """

  require Logger

  alias Ecto.Changeset
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.{BlockNumber, Transactions}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Chain.Import
  alias Explorer.Repo

  @basic_stages [
    Import.Stage.Addresses,
    Import.Stage.AddressReferencing,
    Import.Stage.Transactions,
    Import.Stage.BlockFollowing
  ]

  @other_stages [
    Import.Stage.BlockTokens,
    Import.Stage.BlockAddressTokenBalances,
    Import.Stage.BlockLogs,
    Import.Stage.BlockTokenTransfers,
    Import.Stage.BlockPending
  ]

  @all_stages [
    Import.Stage.Addresses,
    Import.Stage.AddressReferencing,
    Import.Stage.Transactions,
    Import.Stage.BlockPending,
    Import.Stage.BlockTokens,
    Import.Stage.BlockAddressTokenBalances,
    Import.Stage.BlockLogs,
    Import.Stage.BlockTokenTransfers,
    Import.Stage.BlockFollowing
  ]

  # in order so that foreign keys are inserted before being referenced
  @basic_runners Enum.flat_map(@basic_stages, fn stage -> stage.runners() end)
  @other_runners Enum.flat_map(@other_stages, fn stage -> stage.runners() end)
  @all_runners Enum.flat_map(@all_stages, fn stage -> stage.runners() end)

  quoted_runner_option_value =
    quote do
      Import.Runner.options()
    end

  quoted_all_runner_options =
    for runner <- @all_runners do
      quoted_key =
        quote do
          optional(unquote(runner.option_key()))
        end

      {quoted_key, quoted_runner_option_value}
    end

  @type all_options :: %{
          optional(:broadcast) => atom,
          optional(:timeout) => timeout,
          unquote_splicing(quoted_all_runner_options)
        }

  quoted_all_runner_imported =
    for runner <- @all_runners do
      quoted_key =
        quote do
          optional(unquote(runner.option_key()))
        end

      quoted_value =
        quote do
          unquote(runner).imported()
        end

      {quoted_key, quoted_value}
    end

  @type all_result ::
          {:ok, %{unquote_splicing(quoted_all_runner_imported)}}
          | {:error, [Changeset.t()] | :timeout}
          | {:error, step :: Ecto.Multi.name(), failed_value :: any(),
             changes_so_far :: %{optional(Ecto.Multi.name()) => any()}}

  @type timestamps :: %{inserted_at: DateTime.t(), updated_at: DateTime.t()}

  # milliseconds
  @transaction_timeout :timer.minutes(4)

  @imported_table_rows @all_runners
                       |> Stream.map(&Map.put(&1.imported_table_row(), :key, &1.option_key()))
                       |> Enum.map_join("\n", fn %{
                                                   key: key,
                                                   value_type: value_type,
                                                   value_description: value_description
                                                 } ->
                         "| `#{inspect(key)}` | `#{value_type}` | #{value_description} |"
                       end)
  @runner_options_doc Enum.map_join(@all_runners, fn runner ->
                        ecto_schema_module = runner.ecto_schema_module()

                        """
                          * `#{runner.option_key() |> inspect()}`
                            * `:on_conflict` - what to do if a conflict occurs with a pre-existing row: `:nothing`, `:replace_all`, or an
                              `t:Ecto.Query.t/0` to update specific columns.
                            * `:params` - `list` of params for changeset function in `#{ecto_schema_module}`.
                            * `:with` - changeset function to use in `#{ecto_schema_module}`.  Default to `:changeset`.
                            * `:timeout` - the timeout for inserting each batch of changes from `:params`.
                              Defaults to `#{runner.timeout()}` milliseconds.
                        """
                      end)

  @doc """
  Bulk insert all data stored in the `Explorer`.

  The import returns the unique key(s) for each type of record inserted.

  | Key | Value Type | Value Description |
  |-----|------------|-------------------|
  #{@imported_table_rows}

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
  that new data has been inserted. See `Explorer.Chain.Events.Subscriber.to_events/2` for more information.

  ## Options

    * `:broadcast` - Boolean flag indicating whether or not to broadcast the event.
    * `:timeout` - the timeout for the whole `c:Ecto.Repo.transaction/0` call.  Defaults to `#{@transaction_timeout}`
      milliseconds.
  #{@runner_options_doc}
  """
  @spec all(all_options()) :: all_result()
  def all(options) when is_map(options) do
    with {:ok, runner_options_pairs} <- validate_options(options, @basic_runners),
         {:ok, valid_runner_option_pairs} <- validate_runner_options_pairs(runner_options_pairs),
         {:ok, runner_to_changes_list} <- runner_to_changes_list(valid_runner_option_pairs),
         {:ok, data} <- insert_runner_to_changes_list(runner_to_changes_list, options, @basic_stages) do
      %{blocks: blocks, transactions: transactions, fork_transactions: _fork_transactions} = block_data(options, data)

      update_block_cache(blocks)
      update_transactions_cache(transactions)
      Publisher.broadcast(data, Map.get(options, :broadcast, false))

      with {:ok, other_runner_options_pairs} <- validate_options(options, @other_runners),
           {:ok, other_valid_runner_option_pairs} <- validate_runner_options_pairs(other_runner_options_pairs),
           {:ok, other_runner_to_changes_list} <- runner_to_changes_list(other_valid_runner_option_pairs),
           {:ok, other_data} <- insert_runner_to_changes_list(other_runner_to_changes_list, options, @other_stages) do
        merged_data =
          data
          |> Map.merge(other_data)

        Publisher.broadcast(other_data, Map.get(options, :broadcast, false))
        {:ok, merged_data}
      end
    end
  end

  defp block_data(nil, _), do: %{blocks: [], transactions: [], fork_transactions: []}

  defp block_data(%{broadcast: :realtime}, %{
         blocks: blocks,
         transactions: transactions,
         fork_transactions: fork_transactions
       }) do
    %{blocks: blocks, transactions: transactions, fork_transactions: fork_transactions}
  end

  defp block_data(%{broadcast: :realtime}, %{
         blocks: blocks,
         transactions: transactions
       }) do
    %{blocks: blocks, transactions: transactions, fork_transactions: []}
  end

  defp block_data(%{broadcast: :realtime}, %{
         blocks: blocks,
         fork_transactions: fork_transactions
       }) do
    %{blocks: blocks, transactions: [], fork_transactions: fork_transactions}
  end

  defp block_data(%{broadcast: :realtime}, %{
         blocks: blocks
       }) do
    %{blocks: blocks, transactions: [], fork_transactions: []}
  end

  defp block_data(_, _), do: %{blocks: [], transactions: [], fork_transactions: []}

  defp update_block_cache([]), do: :ok

  defp update_block_cache(blocks) when is_list(blocks) do
    {min_block, max_block} = Enum.min_max_by(blocks, & &1.number)

    BlockNumber.update_all(max_block.number)
    BlockNumber.update_all(min_block.number)
    BlocksCache.update(blocks)
  end

  defp update_block_cache(_), do: :ok

  defp update_transactions_cache(transactions) do
    Transactions.update(transactions)
  end

  defp runner_to_changes_list(runner_options_pairs) when is_list(runner_options_pairs) do
    Logger.debug("#blocks_importer#: runner_to_changes_list starting...")

    runner_options_pairs
    |> Stream.map(fn {runner, options} -> runner_changes_list(runner, options) end)
    |> Enum.reduce({:ok, %{}}, fn
      {:ok, {runner, changes_list}}, {:ok, acc_runner_to_changes_list} ->
        Logger.debug("#blocks_importer#: runner_to_changes_list finished")
        {:ok, Map.put(acc_runner_to_changes_list, runner, changes_list)}

      {:ok, _}, {:error, _} = error ->
        Logger.debug("#blocks_importer#: runner_to_changes_list finished")
        error

      {:error, _} = error, {:ok, _} ->
        Logger.debug("#blocks_importer#: runner_to_changes_list finished")
        error

      {:error, runner_changesets}, {:error, acc_changesets} ->
        Logger.debug("#blocks_importer#: runner_to_changes_list finished")
        {:error, acc_changesets ++ runner_changesets}
    end)
  end

  defp runner_changes_list(runner, %{params: params} = options) do
    ecto_schema_module = runner.ecto_schema_module()
    changeset_function_name = Map.get(options, :with, :changeset)
    struct = ecto_schema_module.__struct__()

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

      :ignore, error ->
        {:error, error}
    end)
    |> case do
      {:ok, changes} -> {:ok, {runner, changes}}
      {:error, _} = error -> error
    end
  end

  @global_options ~w(broadcast timeout)a

  defp validate_options(options, runners) when is_map(options) do
    local_options = Map.drop(options, @global_options)

    {reverse_runner_options_pairs, unknown_options} =
      Enum.reduce(runners, {[], local_options}, fn runner, {acc_runner_options_pairs, unknown_options} = acc ->
        option_key = runner.option_key()

        case local_options do
          %{^option_key => option_value} ->
            {[{runner, option_value} | acc_runner_options_pairs], Map.delete(unknown_options, option_key)}

          _ ->
            acc
        end
      end)

    case Enum.empty?(unknown_options) do
      true -> {:ok, Enum.reverse(reverse_runner_options_pairs)}
      # {:error, {:unknown_options, unknown_options}}
      false -> {:ok, Enum.reverse(reverse_runner_options_pairs)}
    end
  end

  defp validate_runner_options_pairs(runner_options_pairs) when is_list(runner_options_pairs) do
    Logger.debug("#blocks_importer#: validate_runner_options_pairs starting...")

    {status, reversed} =
      runner_options_pairs
      |> Stream.map(fn {runner, options} -> validate_runner_options(runner, options) end)
      |> Enum.reduce({:ok, []}, fn
        :ignore, acc ->
          acc

        {:ok, valid_runner_option_pair}, {:ok, valid_runner_options_pairs} ->
          {:ok, [valid_runner_option_pair | valid_runner_options_pairs]}

        {:ok, _}, {:error, _} = error ->
          error

        {:error, reason}, {:ok, _} ->
          {:error, [reason]}

        {:error, reason}, {:error, reasons} ->
          {:error, [reason | reasons]}
      end)

    Logger.debug("#blocks_importer#: validate_runner_options_pairs finished")
    {status, Enum.reverse(reversed)}
  end

  defp validate_runner_options(runner, options) when is_map(options) do
    option_key = runner.option_key()

    runner_specific_options =
      if Map.has_key?(Enum.into(runner.__info__(:functions), %{}), :runner_specific_options) do
        apply(runner, :runner_specific_options, [])
      else
        []
      end

    case {validate_runner_option_params_required(option_key, options),
          validate_runner_options_known(option_key, options, runner_specific_options)} do
      {:ignore, :ok} -> :ignore
      {:ignore, {:error, _} = error} -> error
      {:ok, :ok} -> {:ok, {runner, options}}
      {:ok, {:error, _} = error} -> error
      {{:error, reason}, :ok} -> {:error, [reason]}
      {{:error, reason}, {:error, reasons}} -> {:error, [reason | reasons]}
    end
  end

  defp validate_runner_option_params_required(_, %{params: params}) do
    case Enum.empty?(params) do
      false -> :ok
      true -> :ignore
    end
  end

  defp validate_runner_option_params_required(runner_option_key, _),
    do: {:error, {:required, [runner_option_key, :params]}}

  @local_options ~w(on_conflict params with timeout)a

  defp validate_runner_options_known(runner_option_key, options, runner_specific_options) do
    base_unknown_option_keys = Map.keys(options) -- @local_options
    unknown_option_keys = base_unknown_option_keys -- runner_specific_options

    if Enum.empty?(unknown_option_keys) do
      :ok
    else
      reasons = Enum.map(unknown_option_keys, &{:unknown, [runner_option_key, &1]})

      {:error, reasons}
    end
  end

  defp runner_to_changes_list_to_multis(runner_to_changes_list, options, stages)
       when is_map(runner_to_changes_list) and is_map(options) do
    Logger.debug("#blocks_importer#: runner_to_changes_list_to_multis starting...")
    timestamps = timestamps()
    full_options = Map.put(options, :timestamps, timestamps)

    {multis, final_runner_to_changes_list} =
      Enum.flat_map_reduce(stages, runner_to_changes_list, fn stage, remaining_runner_to_changes_list ->
        stage.multis(remaining_runner_to_changes_list, full_options)
      end)

    unless Enum.empty?(final_runner_to_changes_list) do
      raise ArgumentError,
            "No stages consumed the following runners: #{final_runner_to_changes_list |> Map.keys() |> inspect()}"
    end

    multis
  end

  def insert_changes_list(repo, changes_list, options) when is_atom(repo) and is_list(changes_list) do
    ecto_schema_module = Keyword.fetch!(options, :for)

    timestamped_changes_list = timestamp_changes_list(changes_list, Keyword.fetch!(options, :timestamps))

    {_, inserted} =
      repo.safe_insert_all(
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

  defp insert_runner_to_changes_list(runner_to_changes_list, options, stages) when is_map(runner_to_changes_list) do
    Logger.debug("#blocks_importer#: insert_runner_to_changes_list starting...")

    inserted_runner_to_changes_list =
      runner_to_changes_list
      |> runner_to_changes_list_to_multis(options, stages)
      |> logged_import(options)

    Logger.debug("#blocks_importer#: insert_runner_to_changes_list finished")
    inserted_runner_to_changes_list
  end

  defp logged_import(multis, options) when is_list(multis) and is_map(options) do
    Logger.debug("#blocks_importer#: logged_import starting...")
    import_id = :erlang.unique_integer([:positive])

    Explorer.Logger.metadata(fn -> import_transactions(multis, options) end, import_id: import_id)
  end

  defp import_transactions(multis, options) when is_list(multis) and is_map(options) do
    Logger.debug("#blocks_importer#: import_transactions starting...")

    Enum.reduce_while(multis, {:ok, %{}}, fn multi, {:ok, acc_changes} ->
      case import_transaction(multi, options) do
        {:ok, changes} -> {:cont, {:ok, Map.merge(acc_changes, changes)}}
        {:error, _, _, _} = error -> {:halt, error}
      end
    end)
  rescue
    exception in DBConnection.ConnectionError ->
      case Exception.message(exception) do
        "tcp recv: closed" <> _ -> {:error, :timeout}
        _ -> reraise exception, __STACKTRACE__
      end
  end

  defp import_transaction(multi, options) when is_map(options) do
    Logger.debug("#blocks_importer#: import_transaction starting...")
    Logger.debug(fn -> ["#blocks_importer#: ", inspect(multi)] end)
    Repo.logged_transaction(multi, timeout: Map.get(options, :timeout, @transaction_timeout))
  end

  @spec timestamps() :: timestamps
  def timestamps do
    now = DateTime.utc_now()
    %{inserted_at: now, updated_at: now}
  end
end
