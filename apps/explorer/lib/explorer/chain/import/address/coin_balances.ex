defmodule Explorer.Chain.Import.Address.CoinBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CoinBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Hash, Import, Wei}

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
  def run(multi, changes_list, options) when is_map(options) do
    timestamps = Map.fetch!(options, :timestamps)
    timeout = options[option_key()][:timeout] || @timeout

    Multi.run(multi, :address_coin_balances, fn _ ->
      insert(changes_list, %{timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(
          [
            %{
              required(:address_hash) => Hash.Address.t(),
              required(:block_number) => Block.block_number(),
              required(:value) => Wei.t()
            }
          ],
          %{
            required(:timeout) => timeout,
            required(:timestamps) => Import.timestamps()
          }
        ) ::
          {:ok, [%{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}]}
          | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:address_hash, :block_number],
        on_conflict: on_conflict,
        for: CoinBalance,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, Enum.map(ordered_changes_list, &Map.take(&1, ~w(address_hash block_number)a))}
  end

  def default_on_conflict do
    from(
      balance in CoinBalance,
      update: [
        set: [
          inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", balance.inserted_at),
          updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", balance.updated_at),
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
            )
        ]
      ]
    )
  end
end
