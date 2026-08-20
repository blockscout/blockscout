# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.BackfillScaledUIAmountTokens do
  @moduledoc """
  Rebuilds the [ERC-8056](https://eips.ethereum.org/EIPS/eip-8056) state that can
  be derived from `UIMultiplierUpdated` logs already indexed.

  Every such log of a contract that claims the interface through ERC-165 becomes
  a row of `Explorer.Chain.Token.UIMultiplierChange`, and that contract is typed
  `ERC-8056`. The log alone settles nothing — any contract can emit any topic it
  likes — so the claim is checked before anything is recorded, the same policy
  `Explorer.Token.MetadataRetriever` applies.

  Chains indexed before ERC-8056 support existed hold those logs untouched:
  Blockscout stores every log of every receipt regardless of its topic, it just
  did not interpret this one.

  Without this the history would start at whatever change happened after the
  upgrade, and `Explorer.Chain.Token.UIMultiplierChange.at/4` would resolve
  transfers older than that against an incomplete history.

  The token's own multiplier columns are left alone here. A single past log
  cannot tell what is in force now, and once the type is `ERC-8056` the metadata
  refresh reads the getters anyway.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Ecto.Query

  alias Explorer.Chain.{Hash, Log, Token}
  alias Explorer.Chain.Token.{ScaledUIAmount, UIMultiplierChange}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo
  alias Explorer.Token.MetadataRetriever

  @migration_name "backfill_scaled_ui_amount_tokens"
  @token_type "ERC-8056"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()
    {block_number, index} = last_position(state)

    logs =
      unprocessed_data_query()
      |> where([log], fragment("(?, ?) > (?, ?)", log.block_number, log.index, ^block_number, ^index))
      |> order_by([log], asc: log.block_number, asc: log.index)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    support = resolve_support(logs)
    entries = Enum.map(logs, &entry(&1, support))

    {entries, advance(state, entries)}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    topic = ScaledUIAmount.ui_multiplier_updated_event()

    from(log in Log, as: :log, where: log.first_topic == ^topic)
  end

  @impl FillingMigration
  def update_batch(entries) do
    changes =
      entries
      |> Enum.filter(&match?({_position, %{}, true}, &1))
      |> Enum.map(fn {_position, change, _support} -> change end)

    UIMultiplierChange.insert_changes(changes)

    changes
    |> Enum.map(& &1.token_contract_address_hash)
    |> Enum.uniq()
    |> type_as_scaled_ui_amount()

    length(entries)
  end

  defp entry(log, support) do
    {{log.block_number, log.index}, ScaledUIAmount.parse_known_ui_multiplier_updated(log),
     Map.get(support, log.address_hash, :unknown)}
  end

  defp resolve_support(logs) do
    logs
    |> Enum.map(& &1.address_hash)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Map.new(&{&1, support_of(&1)})
  end

  defp support_of(contract_address_hash) do
    case contract_address_hash |> Hash.to_string() |> MetadataRetriever.scaled_ui_amount_support() do
      {:ok, supports?} ->
        supports?

      :error ->
        Logger.warning(fn ->
          "ERC-165 lookup for #{contract_address_hash} did not reach the node; its logs stay queued"
        end)

        :unknown
    end
  end

  defp advance(state, []), do: state

  defp advance(state, entries) do
    if Enum.any?(entries, &match?({_position, _change, :unknown}, &1)) do
      state
    else
      {position, _change, _support} = List.last(entries)

      Map.put(state, "last_position", Tuple.to_list(position))
    end
  end

  defp last_position(%{"last_position" => [block_number, index]}), do: {block_number, index}
  defp last_position(%{"last_position" => {block_number, index}}), do: {block_number, index}
  defp last_position(_state), do: {-1, -1}

  @impl FillingMigration
  def update_cache, do: :ok

  defp type_as_scaled_ui_amount([]), do: :ok

  defp type_as_scaled_ui_amount(contract_address_hashes) do
    {_count, _} =
      Token
      |> where([token], token.contract_address_hash in ^contract_address_hashes)
      |> where([token], token.type != ^@token_type)
      |> Repo.update_all([set: [type: @token_type, updated_at: DateTime.utc_now()]], timeout: :infinity)

    :ok
  end
end
