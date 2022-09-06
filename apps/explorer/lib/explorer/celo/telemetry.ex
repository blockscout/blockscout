defmodule Explorer.Celo.Telemetry do
  @moduledoc """
    Common telemetry module for Celo Blockscout
  """

  alias __MODULE__

  @doc false
  def start(name, meta \\ %{}, measurements \\ %{}) do
    time = System.monotonic_time()
    measures = Map.put(measurements, :system_time, time)
    :telemetry.execute([:blockscout, name, :start], measures, meta)
    time
  end

  @doc false
  def stop(name, start_time, meta \\ %{}, measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(measurements, %{duration: end_time - start_time})

    :telemetry.execute(
      [:blockscout, name, :stop],
      measurements,
      meta
    )

    end_time
  end

  @doc false
  def exception(event, start_time, kind, reason, stack, meta \\ %{}, extra_measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{duration: end_time - start_time})

    meta =
      meta
      |> Map.put(:kind, kind)
      |> Map.put(:error, reason)
      |> Map.put(:stacktrace, stack)

    :telemetry.execute([:blockscout, event, :exception], measurements, meta)
  end

  @doc false
  def event(name, metrics, meta \\ %{}) do
    :telemetry.execute([:blockscout, name], metrics, meta)
  end

  @doc """
  Wraps a function call with telemetry timing events and an error handler. Errors will be sent with a telemetry event including stack trace before being reraised.

  ## Examples

      Telemetry.wrap(:event_name, call_function())

  will be expanded to

      start = Telemetry.start(:event_name)
      try do
        result = call_function()
        Telemetry.stop(:event_name, start)
        result
      rescue
        e ->
          Telemetry.exception(:event_name, start, :exception, e, __STACKTRACE__)
          reraise e, __STACKTRACE__
      end
  """
  defmacro wrap(event_name, call) do
    quote do
      start_time = Telemetry.start(unquote(event_name))

      try do
        result = unquote(call)
        Telemetry.stop(unquote(event_name), start_time)
        result
      rescue
        e ->
          Telemetry.exception(unquote(event_name), start_time, :exception, e, __STACKTRACE__)
          reraise e, __STACKTRACE__
      end
    end
  end
end
