defmodule Explorer.Chain.Import.TokenTransfers do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.TokenTransfer.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, TokenTransfer}

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [TokenTransfer.t()]

  @impl Import.Runner
  def ecto_schema_module, do: TokenTransfer

  @impl Import.Runner
  def option_key, do: :token_transfers

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

    Multi.run(multi, :token_transfers, fn _ ->
      insert(changes_list, %{timeout: timeout, timestamps: timestamps})
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert([map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [TokenTransfer.t()]}
          | {:error, [Changeset.t()]}
  def insert(changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get(options, :on_conflict, :replace_all)

    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.log_index})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :log_index],
        on_conflict: on_conflict,
        for: TokenTransfer,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
