# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Address.CoinBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CoinBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Hash, Import, Wei}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: CoinBalance

  @impl Import.Runner
  def option_key, do: :address_coin_balances

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{address_hash: Explorer.Chain.Hash.t(), block_number: Explorer.Chain.Block.block_number()}]",
      value_description: "List of  maps of the `t:#{ecto_schema_module()}.t/0` `address_hash` and `block_number`"
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

    Multi.run(multi, :address_coin_balances, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :address_referencing,
        :coin_balances,
        :address_coin_balances
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
              required(:block_number) => Block.block_number(),
              required(:value) => Wei.t()
            }
          ],
          %{
            optional(:on_conflict) => Import.Runner.on_conflict(),
            required(:timeout) => timeout,
            required(:timestamps) => Import.timestamps()
          }
        ) ::
          {:ok, [%{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce CoinBalance ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.address_hash, &1.block_number})
      |> Enum.dedup()

    {:ok, written} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:address_hash, :block_number],
        on_conflict: on_conflict,
        for: CoinBalance,
        returning: [:address_hash, :block_number],
        timeout: timeout,
        timestamps: timestamps
      )

    written_keys = MapSet.new(written, &{&1.address_hash, &1.block_number})

    imported =
      ordered_changes_list
      |> Enum.filter(&imported?(&1, written_keys))
      |> Enum.map(&Map.take(&1, ~w(address_hash block_number value)a))

    {:ok, imported}
  end

  # A row without a value stays in the result whether it was written or not:
  # the importers of blocks, block rewards and internal transactions schedule
  # the fetch of the balances from it, and a block that is imported again (after
  # a reorg, for instance) has to have its balances fetched again even though
  # the rows are already there.
  #
  # A fetched value is in the result only when it was written. The same balance
  # is fetched more than once (by the realtime and the on-demand fetchers, for
  # instance), and a fetch that brings the value already stored writes nothing,
  # so it must not be broadcast again as a new balance of the address.
  defp imported?(changes, written_keys) do
    is_nil(Map.get(changes, :value)) or MapSet.member?(written_keys, {changes.address_hash, changes.block_number})
  end

  @doc """
  The default `ON CONFLICT` clause of the coin balances import.

  A stored balance is replaced only by a value fetched later, and only when it is
  not fetched yet or the new value is different: refetching the same value would
  rewrite the row for nothing, and would make the row look newly imported to the
  readers of the import result.
  """
  @spec default_on_conflict() :: Ecto.Query.t()
  def default_on_conflict do
    from(
      balance in CoinBalance,
      update: [
        set: [
          value:
            fragment(
              """
              CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value_fetched_at > ?) THEN
                     EXCLUDED.value
                   ELSE
                     ?
              END
              """,
              balance.value_fetched_at,
              balance.value_fetched_at,
              balance.value
            ),
          value_fetched_at:
            fragment(
              """
              CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value_fetched_at > ?) THEN
                     EXCLUDED.value_fetched_at
                   ELSE
                     ?
              END
              """,
              balance.value_fetched_at,
              balance.value_fetched_at,
              balance.value_fetched_at
            ),
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", balance.updated_at)
        ]
      ],
      where:
        fragment("EXCLUDED.value IS NOT NULL") and
          (is_nil(balance.value_fetched_at) or
             (fragment("EXCLUDED.value_fetched_at > ?", balance.value_fetched_at) and
                fragment("EXCLUDED.value IS DISTINCT FROM ?", balance.value)))
    )
  end
end
