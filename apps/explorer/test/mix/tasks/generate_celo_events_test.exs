defmodule Explorer.GenerateCeloEventsTest do
  use Explorer.DataCase
  alias Mix.Tasks.GenerateCeloEvents

  describe "generate_topic" do
    test "should match known topics from known abis" do
      test_event_def = %{
        "anonymous" => false,
        "inputs" => [
          %{"indexed" => true, "name" => "account", "type" => "address"},
          %{"indexed" => true, "name" => "group", "type" => "address"},
          %{"indexed" => false, "name" => "value", "type" => "uint256"},
          %{"indexed" => false, "name" => "units", "type" => "uint256"}
        ],
        "name" => "ValidatorGroupVoteActivated",
        "type" => "event"
      }

      topic = GenerateCeloEvents.generate_topic(test_event_def)
      assert topic == "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe"
    end

    test "should handle events without parameters" do
      test_event_def = %{
        "anonymous" => false,
        "inputs" => [],
        "name" => "CoolTestEvent",
        "type" => "event"
      }

      topic = GenerateCeloEvents.generate_topic(test_event_def)
      assert topic == "0xb9269e347396076c10d312e577cb9ec8d8d162ca03ab4fe5388bd6595388647b"
    end
  end

  describe "to_event_properties" do
    test "should handle camel case to snake case" do
      test_event_def = %{
        "anonymous" => false,
        "inputs" => [
          %{"indexed" => true, "name" => "parameterOne", "type" => "address"},
          %{"indexed" => true, "name" => "parameterOnePlusTwo", "type" => "address"}
        ],
        "name" => "TestCamelCaseParamNames",
        "type" => "event"
      }

      result = %{params: params} = GenerateCeloEvents.to_event_properties(test_event_def)

      assert params == [{:parameter_one, :address, :indexed}, {:parameter_one_plus_two, :address, :indexed}]
    end
  end

  describe "extract_events" do
    test "should get all events from contract abi" do
      abi =
        "priv/contracts_abi/celo/election.json"
        |> File.read!()
        |> Jason.decode!()

      events = GenerateCeloEvents.extract_events(abi)

      assert length(events) == 12
    end
  end

  describe "event generation" do
    test "should correctly generate event_param fields" do
      test_event_def = %{
        name: "TestGeneratedEvent",
        params: [
          {:test_param, {:struct, :size}, :indexed}
        ],
        topic: "0xcooltopic"
      }

      struct_string = GenerateCeloEvents.generate_event_struct(:"Test.Module.Name", test_event_def)

      assert struct_string =~ "defmodule Explorer.Celo.ContractEvents.Test.Module.Name",
             "Should define the event module"

      assert struct_string =~ "event_param(:test_param, {:struct, :size}, :indexed)", "Should define an event parameter"
    end
  end
end
