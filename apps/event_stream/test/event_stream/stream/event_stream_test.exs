defmodule EventStream.EventStreamTest do
  use ExUnit.Case
  alias EventStream.ContractEventStream

  import Mox

  setup do
    on_exit(fn ->
      ContractEventStream.clear()
    end)
  end

  setup :set_mox_global
  setup :verify_on_exit!

  test "Enqueue pushes events into the buffer" do
    test_events = [1, 2, 3] |> Enum.map(&generate_event(&1))

    ContractEventStream.enqueue(test_events)

    event_buffer = ContractEventStream.clear()

    assert length(event_buffer |> List.flatten()) == 3
  end

  test "Publishes events on tick" do
    test_events = [1, 2, 3] |> Enum.map(&generate_event(&1))
    ContractEventStream.enqueue(test_events)

    EventStream.Publisher.Mock |> expect(:publish, 3, fn _event -> :ok end)

    send(ContractEventStream, :tick)

    # wait for above message to be processed
    Process.sleep(50)

    event_buffer = ContractEventStream.clear()

    # all events should be published, nothing in buffer
    assert event_buffer == []
  end

  test "Buffers failed event send" do
    test_events = [1, 2, 3] |> Enum.map(&generate_event(&1))
    ContractEventStream.enqueue(test_events)

    EventStream.Publisher.Mock
    |> expect(:publish, fn _event -> :ok end)
    |> expect(:publish, fn event -> {:failed, event} end)
    |> expect(:publish, fn _event -> :ok end)

    send(ContractEventStream, :tick)

    # wait for above message to be processed
    Process.sleep(50)

    EventStream.Publisher.Mock |> expect(:publish, fn _event -> :ok end)
    send(ContractEventStream, :tick)

    # wait for above message to be processed
    Process.sleep(50)

    # buffer should be empty after successful republish
    [] = ContractEventStream.clear()
  end

  # random event taken from staging eventstream
  def generate_event(id) do
    %Explorer.Chain.CeloContractEvent{
      block_number: 17_777_818,
      contract_address_hash: "0x471ece3750da237f93b8e339c536989b8978a438",
      inserted_at: ~U[2023-02-16 14:19:20.260051Z],
      log_index: id,
      name: "Transfer",
      params: %{
        "from" => "\\xb460f9ae1fea4f77107146c1960bb1c978118816",
        "to" => "\\x0ef38e213223805ec1810eebd42153a072a2d89a",
        "value" => 6_177_463_272_192_542
      },
      topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      transaction_hash: "0x7640d07bdc3b51065169b8f6a4720c2f807716f31e40212d81b41dfe1441668b",
      updated_at: ~U[2023-02-16 14:19:20.260051Z]
    }
  end
end
