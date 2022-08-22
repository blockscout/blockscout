defmodule Indexer.Fetcher.EventProcessorTest do
  use Explorer.DataCase, async: false

  import Indexer.Celo.TrackedEventSupport
  alias Indexer.Fetcher.EventProcessor
  alias Indexer.Celo.TrackedEventCache
  alias Explorer.Chain.Celo.TrackedContractEvent

  describe "queueing, processing and importing" do
    test "buffers tracked events and imports" do
      smart_contract = add_trackings([gold_relocked_topic()])
      cache_pid = start_supervised!({TrackedEventCache, [%{}, []]})
      _ = :sys.get_state(cache_pid)

      _pid = Indexer.Fetcher.EventProcessor.Supervisor.Case.start_supervised!()
      logs = gold_relocked_logs(smart_contract.address_hash)

      EventProcessor.enqueue_logs(logs)

      # force batch to be processed
      send(EventProcessor, :flush)

      :timer.sleep(100)

      events = TrackedContractEvent |> Repo.all()
      assert length(events) == 5
    end
  end
end
