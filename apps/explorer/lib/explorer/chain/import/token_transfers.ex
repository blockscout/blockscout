defmodule Explorer.Chain.Import.TokenTransfers do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.TokenTransfer.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Explorer.Chain.{Import, TokenTransfer}

  # milliseconds
  @timeout 60_000

  @type options :: %{
          required(:params) => Import.params(),
          optional(:timeout) => timeout
        }
  @type imported :: [TokenTransfer.t()]

  def run(multi, ecto_schema_module_to_changes_list, options)
      when is_map(ecto_schema_module_to_changes_list) and is_map(options) do
    case ecto_schema_module_to_changes_list do
      %{TokenTransfer => token_transfers_changes} ->
        timestamps = Map.fetch!(options, :timestamps)

        Multi.run(multi, :token_transfers, fn _ ->
          insert(
            token_transfers_changes,
            %{
              timeout: options[:token_transfers][:timeout] || @timeout,
              timestamps: timestamps
            }
          )
        end)

      _ ->
        multi
    end
  end

  def timeout, do: @timeout

  @spec insert([map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [TokenTransfer.t()]}
          | {:error, [Changeset.t()]}
  def insert(changes_list, %{timeout: timeout, timestamps: timestamps})
      when is_list(changes_list) do
    # order so that row ShareLocks are grabbed in a consistent order
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.transaction_hash, &1.log_index})

    {:ok, _} =
      Import.insert_changes_list(
        ordered_changes_list,
        conflict_target: [:transaction_hash, :log_index],
        on_conflict: :replace_all,
        for: TokenTransfer,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end
end
