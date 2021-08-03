defmodule Explorer.Celo.TelemetryTest do
  use ExUnit.Case

  require Explorer.Celo.Telemetry, as: Telemetry

  @doc """
    Create a telemetry event handler that will recieve telemetry events and resend as erlang process messages.

    Accepts the event name and a unique reference to be sent with process messages.
  """
  defmacro test_setup(event_name, ref) do
    event_types =
      [:start, :stop, :exception]
      |> Enum.map(&[:blockscout, event_name, &1])

    quote do
      {test_name, _arity} = __ENV__.function
      parent = self()

      handler = fn event, measurements, meta, _config ->
        send(parent, {unquote(ref), event})
      end

      :telemetry.attach_many(
        to_string(test_name),
        unquote(event_types),
        handler,
        nil
      )
    end
  end

  describe "Test wrapped events" do
    test "Should send start and end events" do
      ref = make_ref()
      test_setup(:wrap_test, ref)

      Telemetry.wrap(:wrap_test, :no_op)

      assert_receive {^ref, [:blockscout, :wrap_test, :start]}
      assert_receive {^ref, [:blockscout, :wrap_test, :stop]}
    end

    test "Should send exception event on errors" do
      ref = make_ref()
      test_setup(:exception_test, ref)

      try do
        Telemetry.wrap(:exception_test, raise("I'm an exception"))
      rescue
        _ ->
          assert_receive {^ref, [:blockscout, :exception_test, :start]}
          assert_receive {^ref, [:blockscout, :exception_test, :exception]}
      else
        _ ->
          flunk("Error should have been raised and messages sent")
      end
    end
  end
end
