defmodule Explorer.Chain.Import.Logs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Log.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, Log}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [Log.t()]

  def run(multi, ecto_schema_module_to_changes_list_map, options)
      when is_map(ecto_schema_module_to_changes_list_map) and is_map(options) do
    case ecto_schema_module_to_changes_list_map do
      %{Log => logs_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        Multi.run(multi, :logs, fn _ ->
          insert(
            logs_changes,
            %{
              timeout: options[:logs][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  @spec insert([map()], %{required(:timeout) => timeout, required(:timestamps) => Import.timestamps()}) ::
          {:ok, [Log.t()]}
          | {:error, [Changeset.t()]}
  defp insert(changes_list, %{timeout: timeout, timestamps: timestamps})
       when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.index})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :index],
        on_conflict: :replace_all,
        for: Log,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
