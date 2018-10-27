defmodule Explorer.Chain.Import.Transaction.Forks do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.Fork.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Explorer.Chain.{Hash, Import, Transaction}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [
          %{required(:uncle_hash) => Hash.Full.t(), required(:hash) => Hash.Full.t()}
        ]

  @impl Import.Runner
  def ecto_schema_module, do: Transaction.Fork

  @impl Import.Runner
  def option_key, do: :transaction_forks

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[%{uncle_hash: Explorer.Chain.Hash.t(), hash: Explorer.Chain.Hash.t()}]",
      value_description: "List of maps of the `t:#{ecto_schema_module()}.t/0` `uncle_hash` and `hash` "
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

    Multi.run(multi, :transaction_forks, fn _ ->
      insert(changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [%{uncle_hash: Hash.t(), hash: Hash.t()}]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.uncle_hash, &1.hash})

    Import.insert_changes_list(
      ordered_changes_list,
      conflict_target: [:uncle_hash, :index],
      on_conflict: on_conflict,
      for: Transaction.Fork,
      returning: [:uncle_hash, :hash],
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      transaction_fork in Transaction.Fork,
      update: [
        set: [
          hash: fragment("EXCLUDED.hash")
        ]
      ]
    )
  end
end
