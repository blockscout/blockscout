defmodule Explorer.Chain.Import.Runner.Address.CurrentTokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CurrentTokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.{Hash, Import}
  alias Explorer.Chain.Import.Runner.{Address.TokenBalances, Tokens}
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.QueryHelper

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CurrentTokenBalance.t()]

  @spec to_holder_address_hash_set_by_token_contract_address_hash([CurrentTokenBalance.t()]) :: %{
          token_contract_address_hash => MapSet.t(holder_address_hash)
        }
        when token_contract_address_hash: Hash.Address.t(), holder_address_hash: Hash.Address.t()
  def to_holder_address_hash_set_by_token_contract_address_hash(address_current_token_balances)
      when is_list(address_current_token_balances) do
    address_current_token_balances
    |> Stream.filter(fn %{value: value} -> valid_holder?(value) end)
    |> Enum.reduce(%{}, fn %{token_contract_address_hash: token_contract_address_hash, address_hash: address_hash},
                           acc_holder_address_hash_set_by_token_contract_address_hash ->
      updated_holder_address_hash_set =
        acc_holder_address_hash_set_by_token_contract_address_hash
        |> Map.get_lazy(token_contract_address_hash, &MapSet.new/0)
        |> MapSet.put(address_hash)

      Map.put(
        acc_holder_address_hash_set_by_token_contract_address_hash,
        token_contract_address_hash,
        updated_holder_address_hash_set
      )
    end)
  end

  @spec token_holder_count_deltas(%{deleted: [current_token_balance], inserted: [current_token_balance]}) :: [
          Tokens.token_holder_count_delta()
        ]
        when current_token_balance: %{
               address_hash: Hash.Address.t(),
               token_contract_address_hash: Hash.Address.t(),
               value: Decimal.t()
             }
  def token_holder_count_deltas(%{deleted: deleted, inserted: inserted}) when is_list(deleted) and is_list(inserted) do
    deleted_holder_address_hash_set_by_token_contract_address_hash =
      to_holder_address_hash_set_by_token_contract_address_hash(deleted)

    inserted_holder_address_hash_set_by_token_contract_address_hash =
      to_holder_address_hash_set_by_token_contract_address_hash(inserted)

    ordered_token_contract_address_hashes =
      ordered_token_contract_address_hashes([
        deleted_holder_address_hash_set_by_token_contract_address_hash,
        inserted_holder_address_hash_set_by_token_contract_address_hash
      ])

    Enum.flat_map(ordered_token_contract_address_hashes, fn token_contract_address_hash ->
      holder_count_delta =
        holder_count_delta(%{
          deleted_holder_address_hash_set_by_token_contract_address_hash:
            deleted_holder_address_hash_set_by_token_contract_address_hash,
          inserted_holder_address_hash_set_by_token_contract_address_hash:
            inserted_holder_address_hash_set_by_token_contract_address_hash,
          token_contract_address_hash: token_contract_address_hash
        })

      case holder_count_delta do
        0 ->
          []

        _ ->
          [%{contract_address_hash: token_contract_address_hash, delta: holder_count_delta}]
      end
    end)
  end

  @impl Import.Runner
  def ecto_schema_module, do: CurrentTokenBalance

  @impl Import.Runner
  def option_key, do: :address_current_token_balances

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    multi
    |> Multi.run(:filter_ctb_placeholders, fn _, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> TokenBalances.filter_placeholders(changes_list) end,
        :block_following,
        :current_token_balances,
        :filter_ctb_placeholders
      )
    end)
    |> Multi.run(:filter_params, fn repo, %{filter_ctb_placeholders: filtered_changes_list} ->
      Instrumenter.block_import_stage_runner(
        fn -> filter_params(repo, filtered_changes_list) end,
        :block_following,
        :current_token_balances,
        :filter_params
      )
    end)
    |> Multi.run(:address_current_token_balances, fn repo, %{filter_params: filtered_changes_list} ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, filtered_changes_list, insert_options) end,
        :block_following,
        :current_token_balances,
        :address_current_token_balances
      )
    end)
    |> Multi.run(:address_current_token_balances_update_token_holder_counts, fn repo,
                                                                                %{
                                                                                  address_current_token_balances:
                                                                                    upserted_balances
                                                                                } ->
      Instrumenter.block_import_stage_runner(
        fn ->
          token_holder_count_deltas = upserted_balances_to_holder_count_deltas(upserted_balances)

          # ShareLocks order already enforced by `acquire_contract_address_tokens` (see docs: sharelocks.md)
          Tokens.update_holder_counts_with_deltas(
            repo,
            token_holder_count_deltas,
            insert_options
          )
        end,
        :block_following,
        :current_token_balances,
        :address_current_token_balances_update_token_holder_counts
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp valid_holder?(value) do
    not is_nil(value) and Decimal.compare(value, 0) == :gt
  end

  # Assumes existence of old_value field with previous value or nil
  defp upserted_balances_to_holder_count_deltas(upserted_balances) do
    upserted_balances
    |> Enum.map(fn %{token_contract_address_hash: contract_address_hash, value: value, old_value: old_value} ->
      delta =
        cond do
          not valid_holder?(old_value) and valid_holder?(value) -> 1
          valid_holder?(old_value) and not valid_holder?(value) -> -1
          true -> 0
        end

      %{contract_address_hash: contract_address_hash, delta: delta}
    end)
    |> Enum.group_by(& &1.contract_address_hash, & &1.delta)
    |> Enum.map(fn {contract_address_hash, deltas} ->
      %{contract_address_hash: contract_address_hash, delta: Enum.sum(deltas)}
    end)
    |> Enum.filter(fn %{delta: delta} -> delta != 0 end)
    |> Enum.sort_by(& &1.contract_address_hash)
  end

  defp holder_count_delta(%{
         deleted_holder_address_hash_set_by_token_contract_address_hash:
           deleted_holder_address_hash_set_by_token_contract_address_hash,
         inserted_holder_address_hash_set_by_token_contract_address_hash:
           inserted_holder_address_hash_set_by_token_contract_address_hash,
         token_contract_address_hash: token_contract_address_hash
       }) do
    case {deleted_holder_address_hash_set_by_token_contract_address_hash[token_contract_address_hash],
          inserted_holder_address_hash_set_by_token_contract_address_hash[token_contract_address_hash]} do
      {deleted_holder_address_hash_set, nil} ->
        -1 * Enum.count(deleted_holder_address_hash_set)

      {nil, inserted_holder_address_hash_set} ->
        Enum.count(inserted_holder_address_hash_set)

      {deleted_holder_address_hash_set, inserted_holder_address_hash_set} ->
        inserted_holder_address_hash_count =
          inserted_holder_address_hash_set
          |> MapSet.difference(deleted_holder_address_hash_set)
          |> Enum.count()

        deleted_holder_address_hash_count =
          deleted_holder_address_hash_set
          |> MapSet.difference(inserted_holder_address_hash_set)
          |> Enum.count()

        inserted_holder_address_hash_count - deleted_holder_address_hash_count
    end
  end

  defp filter_params(repo, changes_list) do
    {params_without_token_id, params_with_token_id} = Enum.split_with(changes_list, &is_nil(&1[:token_id]))

    existing_ctb_without_token_id = select_existing_current_token_balances(repo, params_without_token_id, false)
    existing_ctb_with_token_id = select_existing_current_token_balances(repo, params_with_token_id, true)

    existing_ctb_map =
      existing_ctb_without_token_id
      |> Enum.concat(existing_ctb_with_token_id)
      |> Map.new(fn ctb ->
        {{ctb.address_hash, ctb.token_contract_address_hash, ctb.token_id},
         %{block_number: ctb.block_number, value: ctb.value, value_fetched_at: ctb.value_fetched_at}}
      end)

    filtered_ctbs =
      Enum.filter(changes_list, fn ctb ->
        existing_ctb = existing_ctb_map[{ctb[:address_hash], ctb[:token_contract_address_hash], ctb[:token_id]}]
        should_update?(ctb, existing_ctb)
      end)

    {:ok, filtered_ctbs}
  end

  defp select_existing_current_token_balances(_repo, [], _with_token_id?), do: []

  defp select_existing_current_token_balances(repo, params, false) do
    ids =
      params
      |> Enum.map(&{&1.address_hash.bytes, &1.token_contract_address_hash.bytes})
      |> Enum.uniq()

    existing_ctb_query =
      from(
        ctb in CurrentTokenBalance,
        where: is_nil(ctb.token_id),
        where: ^QueryHelper.tuple_in([:address_hash, :token_contract_address_hash], ids)
      )

    repo.all(existing_ctb_query)
  end

  defp select_existing_current_token_balances(repo, params, true) do
    ids = Enum.map(params, &[&1.address_hash.bytes, &1.token_contract_address_hash.bytes, &1.token_id])

    placeholders =
      ids
      |> Enum.with_index(1)
      |> Enum.map_join(",", fn {_, i} ->
        # The value 3 corresponds to the number of parameters in each group within the WHERE clause.
        # If this number changes, make sure to update it accordingly. For example, placeholders for
        # an array of ids [[1, 2, 3], [4, 5, 6]] would be formatted as: ($1, $2, $3),($4, $5, $6)".
        "($#{3 * i - 2}, $#{3 * i - 1}, $#{3 * i})"
      end)

    # Using raw SQL here is needed to be able to add the `COALESCE` statement
    # which is needed to force `fetched_current_token_balances` full index usage
    existing_ctb_query =
      """
      SELECT address_hash, token_contract_address_hash, token_id, block_number, value, value_fetched_at
      FROM address_current_token_balances
      WHERE (address_hash, token_contract_address_hash, COALESCE(token_id, -1)) IN (#{placeholders})
      """

    query_params = List.flatten(ids)

    existing_ctb_query
    |> repo.query!(query_params)
    |> Map.get(:rows, [])
    |> Enum.map(fn [address_hash, token_contract_address_hash, token_id, block_number, value, value_fetched_at] ->
      %{
        address_hash: address_hash,
        token_contract_address_hash: token_contract_address_hash,
        token_id: token_id,
        block_number: block_number,
        value: value,
        value_fetched_at: value_fetched_at
      }
    end)
  end

  # ctb does not exist
  defp should_update?(_new_ctb, nil), do: true

  # new ctb has no value
  defp should_update?(%{value_fetched_at: nil}, _existing_ctb), do: false

  # new ctb is newer
  defp should_update?(%{block_number: new_ctb_block_number}, %{block_number: existing_ctb_block_number})
       when new_ctb_block_number > existing_ctb_block_number,
       do: true

  # new ctb is the same height or older
  defp should_update?(new_ctb, existing_ctb) do
    existing_ctb.block_number == new_ctb.block_number and not is_nil(Map.get(new_ctb, :value)) and
      (is_nil(existing_ctb.value_fetched_at) or existing_ctb.value_fetched_at < new_ctb.value_fetched_at)
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [CurrentTokenBalance.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options)
       when is_atom(repo) and is_list(changes_list) do
    inserted_changes_list =
      insert_changes_list_with_and_without_token_id(changes_list, repo, timestamps, timeout, options)

    {:ok, inserted_changes_list}
  end

  def insert_changes_list_with_and_without_token_id(changes_list, repo, timestamps, timeout, options) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce CurrentTokenBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.map(fn change ->
        if Map.has_key?(change, :token_id) and
             (Map.get(change, :token_type) == "ERC-1155" || Map.get(change, :token_type) == "ERC-404") do
          change
        else
          Map.put(change, :token_id, nil)
        end
      end)
      |> Enum.group_by(fn %{
                            address_hash: address_hash,
                            token_contract_address_hash: token_contract_address_hash,
                            token_id: token_id
                          } ->
        {address_hash, token_contract_address_hash, token_id}
      end)
      |> Enum.map(fn {_, grouped_address_token_balances} ->
        Enum.max_by(grouped_address_token_balances, fn balance ->
          {Map.get(balance, :block_number), Map.get(balance, :value_fetched_at)}
        end)
      end)
      |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id, &1.address_hash})

    {:ok, inserted_changes_list} =
      if Enum.empty?(ordered_changes_list) do
        {:ok, []}
      else
        Import.insert_changes_list(
          repo,
          ordered_changes_list,
          conflict_target: {:unsafe_fragment, ~s<(address_hash, token_contract_address_hash, COALESCE(token_id, -1))>},
          on_conflict: on_conflict,
          for: CurrentTokenBalance,
          returning: true,
          timeout: timeout,
          timestamps: timestamps
        )
      end

    inserted_changes_list
  end

  defp default_on_conflict do
    from(
      current_token_balance in CurrentTokenBalance,
      update: [
        set: [
          block_number: fragment("EXCLUDED.block_number"),
          value: fragment("EXCLUDED.value"),
          value_fetched_at: fragment("EXCLUDED.value_fetched_at"),
          old_value: current_token_balance.value,
          token_type: fragment("EXCLUDED.token_type"),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", current_token_balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", current_token_balance.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.value_fetched_at IS NOT NULL") and
          (fragment("? < EXCLUDED.block_number", current_token_balance.block_number) or
             (fragment("? = EXCLUDED.block_number", current_token_balance.block_number) and
                fragment("EXCLUDED.value IS NOT NULL") and
                (is_nil(current_token_balance.value_fetched_at) or
                   fragment("? < EXCLUDED.value_fetched_at", current_token_balance.value_fetched_at))))
    )
  end

  defp ordered_token_contract_address_hashes(holder_address_hash_set_by_token_contract_address_hash_list)
       when is_list(holder_address_hash_set_by_token_contract_address_hash_list) do
    holder_address_hash_set_by_token_contract_address_hash_list
    |> Enum.reduce(MapSet.new(), fn holder_address_hash_set_by_token_contract_address_hash, acc ->
      holder_address_hash_set_by_token_contract_address_hash
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.union(acc)
    end)
    |> Enum.sort()
  end
end
