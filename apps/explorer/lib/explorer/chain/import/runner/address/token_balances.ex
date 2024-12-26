defmodule Explorer.Chain.Import.Runner.Address.TokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.TokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Utility.MissingBalanceOfToken

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TokenBalance.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TokenBalance

  @impl Import.Runner
  def option_key, do: :address_token_balances

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
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    multi
    |> Multi.run(:filter_placeholders, fn _, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> filter_placeholders(changes_list) end,
        :block_referencing,
        :token_balances,
        :filter_placeholders
      )
    end)
    |> Multi.run(:address_token_balances, fn repo, %{filter_placeholders: filtered_changes_list} ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, filtered_changes_list, insert_options) end,
        :block_referencing,
        :token_balances,
        :address_token_balances
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @doc """
  Filters out changes with empty `value` or `value_fetched_at` for tokens that doesn't implement `balanceOf` function.
  """
  @spec filter_placeholders([map()]) :: {:ok, [map()]}
  def filter_placeholders(changes_list) do
    {placeholders, filled_balances} =
      Enum.split_with(changes_list, fn balance_params ->
        is_nil(Map.get(balance_params, :value_fetched_at)) or is_nil(Map.get(balance_params, :value))
      end)

    {:ok, filled_balances ++ MissingBalanceOfToken.filter_token_balances_params(placeholders, false)}
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [TokenBalance.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce TokenBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.map(fn change ->
        cond do
          Map.has_key?(change, :token_id) and Map.get(change, :token_type) == "ERC-1155" -> change
          Map.get(change, :token_type) == "ERC-404" and Map.has_key?(change, :token_id) -> Map.put(change, :value, nil)
          Map.get(change, :token_type) == "ERC-404" and Map.has_key?(change, :value) -> Map.put(change, :token_id, nil)
          true -> Map.put(change, :token_id, nil)
        end
      end)
      |> Enum.group_by(fn %{
                            address_hash: address_hash,
                            token_contract_address_hash: token_contract_address_hash,
                            token_id: token_id,
                            block_number: block_number
                          } ->
        {token_contract_address_hash, token_id, address_hash, block_number}
      end)
      |> Enum.map(fn {_, grouped_address_token_balances} ->
        process_grouped_address_token_balances(grouped_address_token_balances)
      end)
      |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id, &1.address_hash, &1.block_number})

    {:ok, inserted_changes_list} =
      if Enum.empty?(ordered_changes_list) do
        {:ok, []}
      else
        Import.insert_changes_list(
          repo,
          ordered_changes_list,
          conflict_target:
            {:unsafe_fragment, ~s<(address_hash, token_contract_address_hash, COALESCE(token_id, -1), block_number)>},
          on_conflict: on_conflict,
          for: TokenBalance,
          returning: true,
          timeout: timeout,
          timestamps: timestamps
        )
      end

    {:ok, inserted_changes_list}
  end

  defp process_grouped_address_token_balances(grouped_address_token_balances) do
    if Enum.count(grouped_address_token_balances) > 1 do
      Enum.max_by(grouped_address_token_balances, fn balance -> Map.get(balance, :value_fetched_at) end)
    else
      Enum.at(grouped_address_token_balances, 0)
    end
  end

  defp default_on_conflict do
    from(
      token_balance in TokenBalance,
      update: [
        set: [
          value: fragment("COALESCE(EXCLUDED.value, ?)", token_balance.value),
          value_fetched_at: fragment("EXCLUDED.value_fetched_at"),
          token_type: fragment("EXCLUDED.token_type"),
          refetch_after: fragment("EXCLUDED.refetch_after"),
          retries_count: fragment("EXCLUDED.retries_count"),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", token_balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", token_balance.updated_at)
        ]
      ],
      where:
        is_nil(token_balance.value_fetched_at) or fragment("EXCLUDED.value_fetched_at IS NULL") or
          fragment("? < EXCLUDED.value_fetched_at", token_balance.value_fetched_at)
    )
  end
end
