defmodule Explorer.Chain.Import.Addresses do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Address.t/0`.
  """

  require Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.{Address, Import}

  import Ecto.Query, only: [from: 2]

  # milliseconds
  @timeout 60_000

  @type imported :: [Address.t()]
  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout,
          optional(:with) => Import.changeset_function_name()
        }

  def run(multi, ecto_schema_module_to_changes_list_map, options)
       when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{Address => addresses_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        Multi.run(multi, :addresses, fn _ ->
          insert(
            addresses_changes,
            %{
              timeout: options[:addresses][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  ## Private Functions

  @spec insert([%{hash: Hash.Address.t()}], %{
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Hash.Address.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps}) when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = sort_changes_list(changes_list)

    Import.insert_changes_list(
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict:
        from(
          address in Address,
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
        ),
      for: Address,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp sort_changes_list(changes_list) do
    Enum.sort_by(changes_list, & &1.hash)
  end
end
