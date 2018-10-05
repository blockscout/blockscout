defmodule Explorer.Chain.Import.Tokens do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Token.t/0`.
  """

  require Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.{Import, Token}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [Token.t()]

  @impl Import.Runner
  def ecto_schema_module, do: Token

  @impl Import.Runner
  def option_key, do: :tokens

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) when is_map(options) do
    %{timestamps: timestamps, tokens: %{on_conflict: on_conflict}} = options
    timeout = options[option_key()][:timeout] || @timeout

    Multi.run(multi, :tokens, fn _ ->
      insert(changes_list, %{on_conflict: on_conflict, timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{
          required(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout(),
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [Token.t()]}
          | {:error, {:required, :on_conflict}}
  def insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    case options do
      %{on_conflict: on_conflict} ->
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

      _ ->
        {:error, {:required, :on_conflict}}
    end
  end
end
