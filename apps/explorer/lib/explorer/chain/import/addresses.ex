defmodule Explorer.Chain.Import.Addresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.t/0`.
  """

  require Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Hash, Import}

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Address.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Address

  @impl Import.Runner
  def option_key, do: :addresses

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

    Multi.run(multi, :addresses, fn _ ->
      insert(changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  ## Private Functions

  @spec insert([%{hash: Hash.Address.t()}], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Address.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = sort_changes_list(changes_list)

    Import.insert_changes_list(
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Address,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(address in Address,
      update: [
        set: [
          contract_code: fragment("COALESCE(?, EXCLUDED.contract_code)", address.contract_code),
          # ARGMAX on two columns
          fetched_coin_balance:
            fragment(
              """
              CASE WHEN EXCLUDED.fetched_coin_balance_block_number IS NOT NULL AND
                        (? IS NULL OR
                         EXCLUDED.fetched_coin_balance_block_number >= ?) THEN
                          EXCLUDED.fetched_coin_balance
                   ELSE ?
              END
              """,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance
            ),
          # MAX on two columns
          fetched_coin_balance_block_number:
            fragment(
              """
              CASE WHEN EXCLUDED.fetched_coin_balance_block_number IS NOT NULL AND
                        (? IS NULL OR
                         EXCLUDED.fetched_coin_balance_block_number >= ?) THEN
                          EXCLUDED.fetched_coin_balance_block_number
                   ELSE ?
              END
              """,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance_block_number,
              address.fetched_coin_balance_block_number
            )
        ]
      ]
    )
  end

  defp sort_changes_list(changes_list) do
    Enum.sort_by(changes_list, & &1.hash)
  end
end
