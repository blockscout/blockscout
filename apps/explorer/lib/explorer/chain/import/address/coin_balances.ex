defmodule Explorer.Chain.Import.Address.CoinBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.CoinBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Chain.{Block, Hash, Import, Wei}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [
          %{required(:address_hash) => Hash.Address.t(), required(:block_number) => Block.block_number()}
        ]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{CoinBalance => balances_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        Multi.run(multi, :address_coin_balances, fn _ ->
          insert(
            balances_changes,
            %{
              timeout: options[:address_coin_balances][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

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
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps}) when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:address_hash, :block_number],
        on_conflict:
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
          ),
        for: CoinBalance,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, Enum.map(ordered_changes_list, &Map.take(&1, ~w(address_hash block_number)a))}
  end
end
