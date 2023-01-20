defmodule Explorer.Celo.Telemetry do
  @moduledoc """
    Common telemetry module for Celo Blockscout
  """

  alias __MODULE__
  require Logger

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
    measurements = Map.merge(measurements, %{duration: end_time - start_time, end_time: end_time})

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

  @doc """
  Emits a telemetry event with given name + included measurements + metadata
  """
  def event(name, measurements \\ %{}, meta \\ %{}) do
    metric_name = normalise_name(name)
    Logger.debug("name=#{inspect(metric_name)} measurements=#{inspect(measurements)} meta=#{inspect(meta)}")
    :telemetry.execute(metric_name, measurements, meta)
  end

  # ensuring that blockscout is tagged at the start of the metric name in both list and string formats
  defp normalise_name(name) when is_atom(name), do: [:blockscout, name]
  defp normalise_name(name = [:blockscout | _]) when is_list(name), do: name
  defp normalise_name(name) when is_list(name), do: [:blockscout | name]

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
