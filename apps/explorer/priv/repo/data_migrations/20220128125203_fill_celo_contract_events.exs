defmodule Explorer.Repo.Migrations.FillCeloContractEvents do
  use Ecto.Migration
  import Ecto.Query

  alias Explorer.Celo.ContractEvents.Election.{
    ValidatorGroupActiveVoteRevokedEvent,
    ValidatorGroupVoteActivatedEvent,
    EpochRewardsDistributedToVotersEvent
  }

  alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent

  @disable_ddl_transaction true
  @disable_migration_lock true
  @batch_size 1000
  @throttle_ms 100

  @topics [
            ValidatorGroupVoteActivatedEvent,
            ValidatorEpochPaymentDistributedEvent,
            ValidatorGroupActiveVoteRevokedEvent,
            EpochRewardsDistributedToVotersEvent
          ]
          |> Enum.map(& &1.topic)

  def up do
    throttle_change_in_batches(&page_query/1, &do_change/1)
  end

  def down, do: execute("delete from celo_contract_events")

  def do_change(to_change) do
    # map block hashes to numbers so we can index into the migration from a given blocknumber + log index for the next
    # batch
    hash_to_number =
      to_change
      |> Enum.reduce(%{}, fn %{block_number: bn, block_hash: bh}, acc ->
        Map.put(acc, bh, bn)
      end)

    params =
      to_change
      |> Explorer.Celo.ContractEvents.EventMap.rpc_to_event_params()
      # explicitly set timestamps as insert_all doesn't do this automatically
      |> then(fn events ->
        t = Timex.now()

        events
        |> Enum.map(fn e ->
          e
          |> Map.put(:inserted_at, t)
          |> Map.put(:updated_at, t)
        end)
      end)

    {inserted_count, results} = repo().insert_all("celo_contract_events", params, returning: [:block_hash, :log_index])

    if inserted_count != length(to_change) do
      not_inserted =
        to_change
        |> Map.take([:block_hash, :log_index])
        |> MapSet.new()
        |> MapSet.difference(MapSet.new(results))
        |> MapSet.to_list()

      not_inserted |> Enum.each(&handle_non_update/1)
    end

    last_key =
      results
      |> Enum.map(fn %{block_hash: hsh, log_index: index} ->
        {Map.get(hash_to_number, hsh), index}
      end)
      |> Enum.max()

    [last_key]
  end

  def page_query({last_block_number, last_index}) do
    from(
      l in "logs",
      select: %{
        first_topic: l.first_topic,
        second_topic: l.second_topic,
        third_topic: l.third_topic,
        fourth_topic: l.fourth_topic,
        data: l.data,
        address_hash: l.address_hash,
        transaction_hash: l.transaction_hash,
        block_number: l.block_number,
        block_hash: l.block_hash,
        index: l.index
      },
      where: l.first_topic in ^@topics and {l.block_number, l.index} > {^last_block_number, ^last_index},
      order_by: [asc: l.block_number, asc: l.index],
      limit: @batch_size
    )
  end

  defp throttle_change_in_batches(query_fun, change_fun, last_pos \\ {0, 0})
  defp throttle_change_in_batches(_query_fun, _change_fun, nil), do: :ok

  defp throttle_change_in_batches(query_fun, change_fun, last_pos) do
    case repo().all(query_fun.(last_pos), log: :info, timeout: :infinity) do
      [] ->
        :ok

      ids ->
        results = change_fun.(List.flatten(ids))
        next_page = results |> Enum.reverse() |> List.first()
        Process.sleep(@throttle_ms)
        throttle_change_in_batches(query_fun, change_fun, next_page)
    end
  end

  defp handle_non_update(id) do
    raise "#{inspect(id)} was not updated"
  end
end
