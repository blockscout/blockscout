defmodule Explorer.Chain.Import.Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.t/0`.
  """

  require Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.{Hash, Import, Transaction}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Hash.Full.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Transaction

  @impl Import.Runner
  def option_key, do: :transactions

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) when is_map(options) do
    %{timestamps: timestamps, transactions: %{on_conflict: on_conflict} = transactions_options} = options
    timeout = transactions_options[:timeout] || @timeout

    Multi.run(multi, :transactions, fn _ ->
      insert(changes_list, %{on_conflict: on_conflict, timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{
          required(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Hash.t()]}
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
