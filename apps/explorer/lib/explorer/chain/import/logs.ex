defmodule Explorer.Chain.Import.Logs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Log.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, Log}

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Log.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Log

  @impl Import.Runner
  def option_key, do: :logs

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

    Multi.run(multi, :logs, fn _ ->
      insert(changes_list, %{timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{required(:timeout) => timeout, required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Log.t()]}
          | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        on_conflict: on_conflict,
        for: Log,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      log in Log,
      update: [
        set: [
          address_hash: fragment("EXCLUDED.address_hash"),
          data: fragment("EXCLUDED.data"),
          first_topic: fragment("EXCLUDED.first_topic"),
          second_topic: fragment("EXCLUDED.second_topic"),
          third_topic: fragment("EXCLUDED.third_topic"),
          fourth_topic: fragment("EXCLUDED.fourth_topic"),
          # Don't update `index` as it is part of the composite primary key and used for the conflict target
          type: fragment("EXCLUDED.type"),
          # Don't update `transaction_hash` as it is part of the composite primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", log.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", log.updated_at)
        ]
      ]
    )
  end
end
