defmodule Explorer.Chain.Import.Address.TokenBalances do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.TokenBalance.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.Import

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
  def run(multi, changes_list, options) when is_map(options) do
    timestamps = Map.fetch!(options, :timestamps)
    timeout = options[option_key()][:timeout] || @timeout

    Multi.run(multi, :address_token_balances, fn _ ->
      insert(changes_list, %{timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [TokenBalance.t()]}
          | {:error, [Changeset.t()]}
  def insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: ~w(address_hash token_contract_address_hash block_number)a,
        on_conflict: on_conflict,
        for: TokenBalance,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
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
    )
  end
end
