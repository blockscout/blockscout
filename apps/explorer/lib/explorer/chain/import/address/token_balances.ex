defmodule Explorer.Chain.Import.Address.TokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.TokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [TokenBalance.t()]

  def run(multi, ecto_schema_module_to_changes_list, options)
      when is_map(ecto_schema_module_to_changes_list) and is_map(options) do
    case ecto_schema_module_to_changes_list do
      %{TokenBalance => token_balances_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        Multi.run(multi, :address_token_balances, fn _ ->
          insert(
            token_balances_changes,
            %{
              timeout: options[:address_token_balances][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  @spec insert([map()], %{
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [TokenBalance.t()]}
          | {:error, [Changeset.t()]}
  def insert(changes_list, %{timeout: timeout, timestamps: timestamps})
      when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: ~w(address_hash token_contract_address_hash block_number)a,
        on_conflict:
          from(
            token_balance in TokenBalance,
            update: [
              set: [
                inserted_at: fragment("LEAST(EXCLUDED.inserted_at, ?)", token_balance.inserted_at),
                updated_at: fragment("GREATEST(EXCLUDED.updated_at, ?)", token_balance.updated_at),
                value:
                  fragment(
                    """
                    CASE WHEN EXCLUDED.value IS NOT NULL AND (? IS NULL OR EXCLUDED.value_fetched_at > ?) THEN
                           EXCLUDED.value
                         ELSE
                           ?
                    END
                    """,
                    token_balance.value_fetched_at,
                    token_balance.value_fetched_at,
                    token_balance.value
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
                    token_balance.value_fetched_at,
                    token_balance.value_fetched_at,
                    token_balance.value_fetched_at
                  )
              ]
            ]
          ),
        for: TokenBalance,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
