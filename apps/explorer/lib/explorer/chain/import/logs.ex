defmodule Explorer.Chain.Import.Logs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Log.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, Log}

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
    on_conflict = Map.get(options, :on_conflict, :replace_all)

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
end
