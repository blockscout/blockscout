defmodule Explorer.Chain.Import.Runner.Optimism.InteropMessages do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Optimism.InteropMessage.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Optimism.InteropMessage
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [InteropMessage.t()]

  @impl Import.Runner
  def ecto_schema_module, do: InteropMessage

  @impl Import.Runner
  def option_key, do: :optimism_interop_messages

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

    Multi.run(multi, :insert_interop_messages, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_interop_messages,
        :optimism_interop_messages
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [InteropMessage.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce InteropMessage ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.nonce, &1.init_chain_id})

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: InteropMessage,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [:nonce, :init_chain_id],
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      message in InteropMessage,
      update: [
        set: [
          # don't update `nonce` as it is a part of the composite primary key and used for the conflict target
          # don't update `init_chain_id` as it is a part of the composite primary key and used for the conflict target
          sender_address_hash: fragment("COALESCE(EXCLUDED.sender_address_hash, ?)", message.sender_address_hash),
          target_address_hash: fragment("COALESCE(EXCLUDED.target_address_hash, ?)", message.target_address_hash),
          init_transaction_hash: fragment("COALESCE(EXCLUDED.init_transaction_hash, ?)", message.init_transaction_hash),
          block_number: fragment("COALESCE(EXCLUDED.block_number, ?)", message.block_number),
          timestamp: fragment("COALESCE(EXCLUDED.timestamp, ?)", message.timestamp),
          relay_chain_id: fragment("EXCLUDED.relay_chain_id"),
          relay_transaction_hash:
            fragment("COALESCE(EXCLUDED.relay_transaction_hash, ?)", message.relay_transaction_hash),
          payload: fragment("COALESCE(EXCLUDED.payload, ?)", message.payload),
          failed: fragment("COALESCE(EXCLUDED.failed, ?)", message.failed),
          transfer_token_address_hash:
            fragment("COALESCE(EXCLUDED.transfer_token_address_hash, ?)", message.transfer_token_address_hash),
          transfer_from_address_hash:
            fragment("COALESCE(EXCLUDED.transfer_from_address_hash, ?)", message.transfer_from_address_hash),
          transfer_to_address_hash:
            fragment("COALESCE(EXCLUDED.transfer_to_address_hash, ?)", message.transfer_to_address_hash),
          transfer_amount: fragment("COALESCE(EXCLUDED.transfer_amount, ?)", message.transfer_amount),
          sent_to_multichain: fragment("COALESCE(EXCLUDED.sent_to_multichain, ?)", message.sent_to_multichain),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", message.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", message.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.sender_address_hash, EXCLUDED.target_address_hash, EXCLUDED.init_transaction_hash, EXCLUDED.block_number, EXCLUDED.timestamp, EXCLUDED.relay_chain_id, EXCLUDED.relay_transaction_hash, EXCLUDED.payload, EXCLUDED.failed, EXCLUDED.transfer_token_address_hash, EXCLUDED.transfer_from_address_hash, EXCLUDED.transfer_to_address_hash, EXCLUDED.transfer_amount) IS DISTINCT FROM (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          message.sender_address_hash,
          message.target_address_hash,
          message.init_transaction_hash,
          message.block_number,
          message.timestamp,
          message.relay_chain_id,
          message.relay_transaction_hash,
          message.payload,
          message.failed,
          message.transfer_token_address_hash,
          message.transfer_from_address_hash,
          message.transfer_to_address_hash,
          message.transfer_amount
        )
    )
  end
end
