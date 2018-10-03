defmodule Explorer.Chain.Import.Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Hash, Import, Transaction}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:with) => Import.changeset_function_name(),
          optional(:on_conflict) => :nothing | :replace_all,
          optional(:timeout) => timeout
        }
  @type imported :: [Hash.Full.t()]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{Transaction => transactions_changes} ->
        # check required options as early as possible
        %{timestamps: timestamps, transactions: %{on_conflict: on_conflict} = transactions_options} = options

        Multi.run(multi, :transactions, fn _ ->
          insert(
            transactions_changes,
            %{
              on_conflict: on_conflict,
              timeout: transactions_options[:timeout] || @timeout,
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
          required(:on_conflict) => Import.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Hash.t()]} | {:error, [Changeset.t()]}
  defp insert(changes_list, %{on_conflict: on_conflict, timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.hash)

    {:ok, transactions} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: :hash,
        on_conflict: on_conflict,
        for: Transaction,
        returning: [:hash],
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, for(transaction <- transactions, do: transaction.hash)}
  end
end
