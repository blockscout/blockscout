defmodule Explorer.Chain.Import.Tokens do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Token.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, Token}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:on_conflict) => :nothing | :replace_all,
          optional(:timeout) => timeout
        }
  @type imported :: [Token.t()]

  def run(multi, ecto_schema_module_to_changes_list, options)
      when is_map(ecto_schema_module_to_changes_list) and is_map(options) do
    case ecto_schema_module_to_changes_list do
      %{Token => tokens_changes} ->
        %{timestamps: timestamps, tokens: %{on_conflict: on_conflict}} = options

        Multi.run(multi, :tokens, fn _ ->
          insert(
            tokens_changes,
            %{
              on_conflict: on_conflict,
              timeout: options[:tokens][:timeout] || @timeout,
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
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Token.t()]}
          | {:error, [Changeset.t()]}
  def insert(changes_list, %{on_conflict: on_conflict, timeout: timeout, timestamps: timestamps})
      when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, & &1.contract_address_hash)

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: :contract_address_hash,
        on_conflict: on_conflict,
        for: Token,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
