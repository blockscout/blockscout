defmodule Explorer.Chain.Import.Runner.Transactions do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Transaction.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Multi, Repo}
  alias Explorer.Chain.{Data, Hash, Import, Transaction}

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
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :transactions, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) :: {:ok, [Hash.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: %{inserted_at: inserted_at} = timestamps} = options)
       when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    ordered_changes_list =
      changes_list
      |> timestamp_ok_value_transfers(inserted_at)
      # order so that row ShareLocks are grabbed in a consistent order
      |> Enum.sort_by(& &1.hash)

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: :hash,
      on_conflict: on_conflict,
      for: Transaction,
      returning: ~w(block_number index hash internal_transactions_indexed_at)a,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    from(
      transaction in Transaction,
      update: [
        set: [
          block_hash: fragment("EXCLUDED.block_hash"),
          block_number: fragment("EXCLUDED.block_number"),
          created_contract_address_hash: fragment("EXCLUDED.created_contract_address_hash"),
          cumulative_gas_used: fragment("EXCLUDED.cumulative_gas_used"),
          error: fragment("EXCLUDED.error"),
          from_address_hash: fragment("EXCLUDED.from_address_hash"),
          gas: fragment("EXCLUDED.gas"),
          gas_price: fragment("EXCLUDED.gas_price"),
          gas_used: fragment("EXCLUDED.gas_used"),
          index: fragment("EXCLUDED.index"),
          internal_transactions_indexed_at: fragment("EXCLUDED.internal_transactions_indexed_at"),
          input: fragment("EXCLUDED.input"),
          nonce: fragment("EXCLUDED.nonce"),
          r: fragment("EXCLUDED.r"),
          s: fragment("EXCLUDED.s"),
          status: fragment("EXCLUDED.status"),
          to_address_hash: fragment("EXCLUDED.to_address_hash"),
          v: fragment("EXCLUDED.v"),
          value: fragment("EXCLUDED.value"),
          # Don't update `hash` as it is part of the primary key and used for the conflict target
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", transaction.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", transaction.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.block_hash, EXCLUDED.block_number, EXCLUDED.created_contract_address_hash, EXCLUDED.cumulative_gas_used, EXCLUDED.cumulative_gas_used, EXCLUDED.from_address_hash, EXCLUDED.gas, EXCLUDED.gas_price, EXCLUDED.gas_used, EXCLUDED.index, EXCLUDED.internal_transactions_indexed_at, EXCLUDED.input, EXCLUDED.nonce, EXCLUDED.r, EXCLUDED.s, EXCLUDED.status, EXCLUDED.to_address_hash, EXCLUDED.v, EXCLUDED.value) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          transaction.block_hash,
          transaction.block_number,
          transaction.created_contract_address_hash,
          transaction.cumulative_gas_used,
          transaction.cumulative_gas_used,
          transaction.from_address_hash,
          transaction.gas,
          transaction.gas_price,
          transaction.gas_used,
          transaction.index,
          transaction.internal_transactions_indexed_at,
          transaction.input,
          transaction.nonce,
          transaction.r,
          transaction.s,
          transaction.status,
          transaction.to_address_hash,
          transaction.v,
          transaction.value
        )
    )
  end

  defp timestamp_ok_value_transfers(changes_list, timestamp) when is_list(changes_list) do
    Enum.map(changes_list, &timestamp_ok_value_transfer(&1, timestamp))
  end

  # A post-Byzantium validated transaction will have a status and if it has no input, it is a value transfer only.
  # Internal transactions are only needed when status is `:error` to set `error`.
  defp timestamp_ok_value_transfer(%{status: :ok, input: %Data{bytes: <<>>}} = changes, timestamp) do
    Map.put(changes, :internal_transactions_indexed_at, timestamp)
  end

  defp timestamp_ok_value_transfer(changes, _), do: changes
end
