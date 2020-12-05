defmodule Explorer.Chain.Import.Runner.Address.CurrentTokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CurrentTokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.{Hash, Import}
  alias Explorer.Chain.Import.Runner.Tokens

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

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    multi
    |> Multi.run(:acquire_contract_address_tokens, fn repo, _ ->
      contract_address_hashes = changes_list |> Enum.map(& &1.token_contract_address_hash) |> Enum.uniq()
      Tokens.acquire_contract_address_tokens(repo, contract_address_hashes)
    end)
    |> Multi.run(:address_current_token_balances, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
    |> Multi.run(:address_current_token_balances_update_token_holder_counts, fn repo,
                                                                                %{
                                                                                  address_current_token_balances:
                                                                                    upserted_balances
                                                                                } ->
      token_holder_count_deltas = upserted_balances_to_holder_count_deltas(upserted_balances)

      # ShareLocks order already enforced by `acquire_contract_address_tokens` (see docs: sharelocks.md)
      Tokens.update_holder_counts_with_deltas(
        repo,
        token_holder_count_deltas,
        insert_options
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp valid_holder?(value) do
    not is_nil(value) and Decimal.cmp(value, 0) == :gt
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

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [CurrentTokenBalance.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options)
       when is_atom(repo) and is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce CurrentTokenBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.token_contract_address_hash, &1.address_hash})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: ~w(address_hash token_contract_address_hash)a,
      on_conflict: on_conflict,
      for: CurrentTokenBalance,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
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
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", current_token_balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", current_token_balance.updated_at)
        ]
      ],
      where:
        fragment("? < EXCLUDED.block_number", current_token_balance.block_number) or
          (fragment("EXCLUDED.value IS NOT NULL") and
             is_nil(current_token_balance.value_fetched_at) and
             fragment("? = EXCLUDED.block_number", current_token_balance.block_number))
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
