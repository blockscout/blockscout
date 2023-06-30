defmodule Explorer.Chain.Import.Runner.Address.CoinBalancesDaily do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CoinBalancesDaily.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CoinBalanceDaily
  alias Explorer.Chain.{Hash, Import, Wei}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:address_hash) => Hash.Address.t(), required(:day) => Date.t()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: CoinBalanceDaily

  @impl Import.Runner
  def option_key, do: :address_coin_balances_daily

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{address_hash: Explorer.Chain.Hash.t(), day: Date.t()}]",
      value_description: "List of  maps of the `t:#{ecto_schema_module()}.t/0` `address_hash` and `day`"
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

    Multi.run(multi, :address_coin_balances_daily, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :address_referencing,
        :coin_balances_daily,
        :address_coin_balances_daily
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(
          Repo.t(),
          [
            %{
              required(:address_hash) => Hash.Address.t(),
              required(:day) => Date.t(),
              required(:value) => Wei.t()
            }
          ],
          %{
            optional(:on_conflict) => Import.Runner.on_conflict(),
            required(:timeout) => timeout,
            required(:timestamps) => Import.timestamps()
          }
        ) ::
          {:ok, [%{required(:address_hash) => Hash.Address.t(), required(:day) => Date.t()}]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    combined_changes = changes_list |> Enum.reduce(%{}, &compose_change/2)

    # Enforce CoinBalanceDaily ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = combined_changes |> Map.values() |> Enum.sort_by(&{&1.address_hash, &1.day})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:address_hash, :day],
        on_conflict: on_conflict,
        for: CoinBalanceDaily,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, Enum.map(ordered_changes_list, &Map.take(&1, ~w(address_hash day)a))}
  end

  defp compose_change(change, acc) do
    Map.update(acc, {change.address_hash, change.day}, change, fn existing_change ->
      if Map.has_key?(change, :value) && Map.has_key?(existing_change, :value) &&
           change.value > existing_change.value do
        change
      else
        existing_change
      end
    end)
  end

  def default_on_conflict do
    from(
      balance in CoinBalanceDaily,
      update: [
        set: [
          value:
            fragment(
              """
              CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value > ?) THEN
                     EXCLUDED.value
                   ELSE
                     ?
              END
              """,
              balance.value,
              balance.value,
              balance.value
            ),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", balance.updated_at)
        ]
      ],
      where: fragment("EXCLUDED.value IS NOT NULL")
    )
  end
end
