defmodule Indexer.Celo.TrackedEventCacheTest do
  use Explorer.DataCase, async: false
  import Explorer.Factory
  import Indexer.Celo.TrackedEventSupport

  alias Explorer.Chain.Celo.{ContractEventTracking, TrackedContractEvent}
  alias Explorer.Chain.{Log, SmartContract}
  alias Indexer.Celo.TrackedEventCache

  describe "populates cache" do
    test "populates ets with cached events" do
      smart_contract = add_trackings([gold_unlocked_topic()])

      cache_pid = start_supervised!({TrackedEventCache, [%{}, []]})

      # force handle_continue to complete before continuing with test
      _ = :sys.get_state(cache_pid)

      cached_event = :ets.lookup(TrackedEventCache, {gold_unlocked_topic(), smart_contract.address_hash |> to_string()})
      refute cached_event == []
    end

    test "rebuilds cache on command" do
      smart_contract = add_trackings([gold_unlocked_topic()])
      cache_pid = start_supervised!({TrackedEventCache, [%{}, []]})

      # force handle_continue to complete before continuing with test
      _ = :sys.get_state(cache_pid)

      _ = add_trackings([gold_relocked_topic(), slasher_whitelist_added_topic()], smart_contract)

      TrackedEventCache.rebuild_cache()

      [gold_relocked_topic(), gold_unlocked_topic(), slasher_whitelist_added_topic()]
      |> Enum.each(fn topic ->
        search_tuple = {topic, smart_contract.address_hash |> to_string()}
        refute :ets.lookup(TrackedEventCache, search_tuple) == []
      end)
    end
  end

  describe "filters events" do
    test "filters out untracked events" do
      event_topics = [gold_unlocked_topic(), gold_relocked_topic(), slasher_whitelist_added_topic()]
      smart_contract = add_trackings(event_topics)
      cache_pid = start_supervised!({TrackedEventCache, [%{}, []]})
      _ = :sys.get_state(cache_pid)

      logs =
        1..20
        |> Enum.map(fn _ -> insert(:log) end)

      relevant_logs =
        event_topics
        |> Enum.map(fn topic ->
          log = insert(:log, %{first_topic: topic})
          %{log | address_hash: smart_contract.address_hash}
        end)

      filtered_list = TrackedEventCache.filter_tracked(logs ++ relevant_logs)

      assert length(filtered_list) == 3
    end
  end

  describe "batches events" do
    test "batches up single event for processing" do
      smart_contract = add_trackings([gold_relocked_topic()])
      cache_pid = start_supervised!({TrackedEventCache, [%{}, []]})
      _ = :sys.get_state(cache_pid)

      logs = gold_relocked_logs(smart_contract.address_hash)

      assert [{^logs, %ABI.FunctionSelector{function: "GoldRelocked"}, _tracking_id}] =
               TrackedEventCache.batch_events(logs)
    end
  end
end
