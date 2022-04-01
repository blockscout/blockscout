defmodule Explorer.Repo.Migrations.FillCeloContractEvents do
  use Ecto.Migration
  import Ecto.Query

  alias Explorer.Celo.ContractEvents.Election.{
    ValidatorGroupActiveVoteRevokedEvent,
    ValidatorGroupVoteActivatedEvent,
    EpochRewardsDistributedToVotersEvent
  }

  alias Explorer.Chain.Hash.{Address, Full}

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
    params =
      to_change
      |> Explorer.Celo.ContractEvents.EventMap.rpc_to_event_params()
      # explicitly set timestamps as insert_all doesn't do this automatically
      |> then(fn events ->
        t = Timex.now()

        events
        |> Enum.map(fn event ->
          {:ok, contract_address_hash} = Address.dump(event.contract_address_hash)

          event =
            case event.transaction_hash do
              nil ->
                event

              hash ->
                {:ok, transaction_hash} = Full.dump(hash)
                event |> Map.put(:transaction_hash, transaction_hash)
            end

          event
          |> Map.put(:inserted_at, t)
          |> Map.put(:updated_at, t)
          |> Map.put(:contract_address_hash, contract_address_hash)
        end)
      end)

    {inserted_count, results} =
      Explorer.Repo.insert_all("celo_contract_events", params, returning: [:block_number, :log_index])

    if inserted_count != length(to_change) do
      not_inserted =
        to_change
        |> Enum.map(&Map.take(&1, [:block_number, :log_index]))
        |> MapSet.new()
        |> MapSet.difference(MapSet.new(results))
        |> MapSet.to_list()

      not_inserted |> Enum.each(&handle_non_update/1)
    end

    last_key =
      results
      |> Enum.map(fn %{block_number: block_number, log_index: index} -> {block_number, index} end)
      |> Enum.max()

    [last_key]
  end

  def page_query({last_block_number, last_index}) do
    from(
      l in "logs",
      left_join: e in "celo_contract_events",
      on: e.topic == l.first_topic and e.block_number == l.block_number and e.log_index == l.index,
      select: %{
        first_topic: l.first_topic,
        second_topic: l.second_topic,
        third_topic: l.third_topic,
        fourth_topic: l.fourth_topic,
        data: l.data,
        address_hash: l.address_hash,
        transaction_hash: l.transaction_hash,
        block_number: l.block_number,
        index: l.index
      },
      where:
        is_nil(e.topic) and l.first_topic in ^@topics and {l.block_number, l.index} > {^last_block_number, ^last_index},
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
