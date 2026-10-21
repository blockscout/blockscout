# SPDX-License-Identifier: LicenseRef-Blockscout
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

  @typedoc """
  A current token balance row shape carrying enough fields to decide whether
  it makes its address a holder of its token: `value > 0`, or any row of an
  `ERC-7984` token (confidential balances), except for the burn address —
  matching `Explorer.Chain.Address.CurrentTokenBalance.token_holders_query_for_count/1`.
  """
  @type holder_row :: %{
          required(:address_hash) => Hash.Address.t(),
          required(:token_contract_address_hash) => Hash.Address.t(),
          required(:token_id) => Decimal.t() | nil,
          required(:token_type) => String.t() | nil,
          required(:value) => Decimal.t() | nil,
          optional(atom()) => any()
        }

  @doc """
  Computes the holder-count deltas produced by a reorg: `deleted` are the
  current token balance rows removed with the non-consensus blocks, `inserted`
  the rows re-derived from the historical token balances. A `{token, address}`
  pair contributes ±1 only when its holder-ness actually flipped, taking the
  pair's untouched rows (other `token_id`s still in the DB) into account.
  """
  @spec token_holder_count_deltas(Repo.t(), %{deleted: [holder_row()], inserted: [holder_row()]}, timeout()) :: [
          Tokens.token_holder_count_delta()
        ]
  def token_holder_count_deltas(repo, %{deleted: deleted, inserted: inserted}, timeout \\ @timeout)
      when is_list(deleted) and is_list(inserted) do
    deleted = Enum.reject(deleted, &burn_address?(&1.address_hash))
    inserted = Enum.reject(inserted, &burn_address?(&1.address_hash))

    before_by_pair = rows_qualification_by_pair(deleted)
    after_by_pair = rows_qualification_by_pair(inserted)

    pair_states =
      (Map.keys(before_by_pair) ++ Map.keys(after_by_pair))
      |> Enum.uniq()
      |> Map.new(fn pair ->
        {pair, %{before?: Map.get(before_by_pair, pair, false), after?: Map.get(after_by_pair, pair, false)}}
      end)

    # the re-inserted rows are the only reorg-touched rows still present in
    # the DB (deleted-but-not-reinserted rows are gone), so excluding the
    # inserted triples leaves exactly the pair rows untouched by the reorg
    batch_triples = MapSet.new(inserted, &row_triple/1)

    pair_transition_deltas(repo, pair_states, batch_triples, timeout)
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
    |> Multi.run(:address_current_token_balances, fn repo, %{filter_params: {filtered_changes_list, _existing_keys}} ->
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
                                                                                    upserted_balances,
                                                                                  filter_params: {_, existing_keys}
                                                                                } ->
      Instrumenter.block_import_stage_runner(
        fn ->
          token_holder_count_deltas = upserted_balances_to_holder_count_deltas(repo, upserted_balances, existing_keys)

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

  # matches the semantics of `CurrentTokenBalance.token_holders_query_for_count/1`:
  # any row of an ERC-7984 token counts (confidential balances), otherwise value > 0
  defp row_qualifies?(%{token_type: "ERC-7984"}), do: true
  defp row_qualifies?(%{value: value}), do: valid_holder?(value)

  # whether the row made its address a holder BEFORE this upsert: freshly
  # inserted rows did not exist; updated ERC-7984 rows existed (any row
  # counts); otherwise the previous value decides (`old_value` is set to the
  # pre-upsert value by the on_conflict clause)
  defp old_row_qualifies?(row, existing_keys) do
    if MapSet.member?(existing_keys, row_triple(row)) do
      case row.token_type do
        "ERC-7984" -> true
        _ -> valid_holder?(row.old_value)
      end
    else
      false
    end
  end

  defp rows_qualification_by_pair(rows) do
    rows
    |> Enum.group_by(&{&1.token_contract_address_hash, &1.address_hash})
    |> Map.new(fn {pair, pair_rows} -> {pair, Enum.any?(pair_rows, &row_qualifies?/1)} end)
  end

  defp burn_address?(%Hash{bytes: bytes}), do: bytes == <<0::160>>

  defp row_triple(row) do
    {row.address_hash.bytes, row.token_contract_address_hash.bytes, normalize_token_id(row.token_id)}
  end

  defp normalize_token_id(nil), do: nil
  defp normalize_token_id(%Decimal{} = token_id), do: Decimal.to_integer(token_id)
  defp normalize_token_id(token_id) when is_integer(token_id), do: token_id

  # Computes the holder-count deltas of the freshly upserted current token
  # balance rows: a {token, address} pair contributes ±1 only when its
  # holder-ness actually flipped with this batch, taking the pair's other rows
  # (untouched token_ids of ERC-1155/404 balances) into account.
  defp upserted_balances_to_holder_count_deltas(repo, upserted_balances, existing_keys) do
    pair_states =
      upserted_balances
      |> Enum.reject(&burn_address?(&1.address_hash))
      |> Enum.group_by(&{&1.token_contract_address_hash, &1.address_hash})
      |> Map.new(fn {pair, rows} ->
        {pair,
         %{
           before?: Enum.any?(rows, &old_row_qualifies?(&1, existing_keys)),
           after?: Enum.any?(rows, &row_qualifies?/1)
         }}
      end)

    batch_triples = MapSet.new(upserted_balances, &row_triple/1)

    pair_transition_deltas(repo, pair_states, batch_triples, @timeout)
  end

  # For every {token, address} pair whose holder-ness flipped within the
  # batch, checks whether the pair has other qualifying rows outside the batch
  # (then its holder-ness did not actually change) and folds the surviving
  # flips into per-token deltas.
  defp pair_transition_deltas(repo, pair_states, batch_triples, timeout) do
    flipped = for {pair, %{before?: before?, after?: after?}} <- pair_states, before? != after?, do: {pair, after?}

    pairs_with_other_rows =
      pairs_with_other_qualifying_rows(repo, Enum.map(flipped, fn {pair, _after?} -> pair end), batch_triples, timeout)

    flipped
    |> Enum.reject(fn {pair, _after?} -> MapSet.member?(pairs_with_other_rows, pair) end)
    |> Enum.map(fn {{token_contract_address_hash, _address_hash}, after?} ->
      %{contract_address_hash: token_contract_address_hash, delta: if(after?, do: 1, else: -1)}
    end)
    |> Enum.group_by(& &1.contract_address_hash, & &1.delta)
    |> Enum.map(fn {contract_address_hash, deltas} ->
      %{contract_address_hash: contract_address_hash, delta: Enum.sum(deltas)}
    end)
    |> Enum.filter(fn %{delta: delta} -> delta != 0 end)
    |> Enum.sort_by(& &1.contract_address_hash)
  end

  defp pairs_with_other_qualifying_rows(_repo, [], _batch_triples, _timeout), do: MapSet.new()

  defp pairs_with_other_qualifying_rows(repo, pairs, batch_triples, timeout) do
    ids =
      Enum.map(pairs, fn {token_contract_address_hash, address_hash} ->
        {address_hash.bytes, token_contract_address_hash.bytes}
      end)

    query =
      from(ctb in CurrentTokenBalance,
        where: ^QueryHelper.tuple_in([:address_hash, :token_contract_address_hash], ids),
        where: ctb.value > 0 or ctb.token_type == "ERC-7984",
        select: {ctb.token_contract_address_hash, ctb.address_hash, ctb.token_id}
      )

    query
    |> repo.all(timeout: timeout)
    |> Enum.reduce(MapSet.new(), fn {token_contract_address_hash, address_hash, token_id}, acc ->
      triple = {address_hash.bytes, token_contract_address_hash.bytes, normalize_token_id(token_id)}

      if MapSet.member?(batch_triples, triple) do
        acc
      else
        MapSet.put(acc, {token_contract_address_hash, address_hash})
      end
    end)
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

    existing_keys =
      existing_ctb_without_token_id
      |> Enum.concat(existing_ctb_with_token_id)
      |> MapSet.new(fn ctb ->
        {hash_bytes(ctb.address_hash), hash_bytes(ctb.token_contract_address_hash), normalize_token_id(ctb.token_id)}
      end)

    filtered_ctbs =
      Enum.filter(changes_list, fn ctb ->
        existing_ctb = existing_ctb_map[{ctb[:address_hash], ctb[:token_contract_address_hash], ctb[:token_id]}]
        should_update?(Map.put_new(ctb, :value_fetched_at, nil), existing_ctb)
      end)

    {:ok, {filtered_ctbs, existing_keys}}
  end

  defp hash_bytes(%Hash{bytes: bytes}), do: bytes
  defp hash_bytes(bytes) when is_binary(bytes), do: bytes

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

  # new ctb is newer
  defp should_update?(%{block_number: new_ctb_block_number}, %{block_number: existing_ctb_block_number})
       when new_ctb_block_number > existing_ctb_block_number,
       do: true

  # new ctb is the same height or older
  defp should_update?(new_ctb, existing_ctb) do
    existing_ctb.block_number == new_ctb.block_number and not is_nil(Map.get(new_ctb, :value)) and
      (is_nil(existing_ctb.value_fetched_at) or Timex.before?(existing_ctb.value_fetched_at, new_ctb.value_fetched_at))
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
          value: fragment("COALESCE(EXCLUDED.value, ?)", current_token_balance.value),
          value_fetched_at: fragment("EXCLUDED.value_fetched_at"),
          old_value: current_token_balance.value,
          token_type: fragment("EXCLUDED.token_type"),
          refetch_after: fragment("EXCLUDED.refetch_after"),
          retries_count: fragment("EXCLUDED.retries_count"),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", current_token_balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", current_token_balance.updated_at)
        ]
      ],
      where:
        fragment("? < EXCLUDED.block_number", current_token_balance.block_number) or
          (fragment("? = EXCLUDED.block_number", current_token_balance.block_number) and
             fragment("EXCLUDED.value_fetched_at IS NOT NULL") and
             fragment("EXCLUDED.value IS NOT NULL") and
             (is_nil(current_token_balance.value_fetched_at) or
                fragment("? < EXCLUDED.value_fetched_at", current_token_balance.value_fetched_at)))
    )
  end
end
