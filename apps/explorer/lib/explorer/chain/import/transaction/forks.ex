defmodule Explorer.Chain.Import.Transaction.Forks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.Fork.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Explorer.Chain.{Hash, Import, Transaction}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [
          %{required(:uncle_hash) => Hash.Full.t(), required(:hash) => Hash.Full.t()}
        ]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{Transaction.Fork => transaction_fork_changes} ->
        %{timestamps: timestamps} = options

        Multi.run(multi, :transaction_forks, fn _ ->
          insert(
            transaction_fork_changes,
            %{
              timeout: options[:transaction_forks][:timeout] || @timeout,
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
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [%{uncle_hash: Hash.t(), hash: Hash.t()}]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.uncle_hash, &1.hash})

    Import.insert_changes_list(
      ordered_changes_list,
      conflict_target: [:uncle_hash, :index],
      on_conflict:
        from(
          transaction_fork in Transaction.Fork,
          update: [
            set: [
              hash: fragment("EXCLUDED.hash")
            ]
          ]
        ),
      for: Transaction.Fork,
      returning: [:uncle_hash, :hash],
      timeout: timeout,
      timestamps: timestamps
    )
  end
end
