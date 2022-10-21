defmodule Indexer.Prometheus.CeloInstrumenter do
  @moduledoc "Instrumentation for Celo telemetry"

  use Prometheus.Metric
  require Logger

  def setup do
    event_config = Application.get_env(:indexer, :telemetry_config)

    event_config |> Enum.each(&configure_event(&1))
  end

  def configure_event(event_config) do
    case process_config(event_config) do
      [name, type, label, meta] ->
        attach_event(name, type, label, meta)

      {:error, msg} ->
        Logger.error("Error configuring event #{inspect(event_config)}: #{msg}")
    end
  end

  def attach_event(name, :summary, label, %{metric_labels: metric_labels, help: help} = meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Summary.declare(
      name: label,
      labels: metric_labels,
      help: help
    )

    handler_meta = meta |> Map.merge(%{type: :summary, label: label})

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, handler_meta)
  end

  def attach_event(name, :counter, label, %{help: help} = meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Counter.declare(
      name: label,
      help: help
    )

    handler_meta = meta |> Map.merge(%{type: :counter, label: label})

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, handler_meta)
  end

  def attach_event(name, :histogram, label, %{buckets: buckets, metric_labels: metric_labels, help: help} = _meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Histogram.new(
      name: label,
      buckets: buckets,
      duration_unit: false,
      labels: metric_labels,
      help: help
    )

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, %{type: :histogram, label: label})
  end

  def attach_event(name, _type, _label, _meta), do: Logger.info("Unhandled metric attach request: #{name |> inspect()}")

  defp handler_id(event_name), do: "event_handler_id_#{event_name |> Enum.join() |> to_string()}"

  def handle_event(_name, _measurements, _metadata, %{type: :counter, label: label}) do
    Counter.inc(name: label)
  end

  def handle_event(_name, measurements, _metadata, %{type: :histogram, label: label} = meta)
      when is_map(measurements) do
    measurements
    |> process_measurements(meta)
    |> Enum.each(fn {name, value} ->
      Histogram.observe(
        [name: label, labels: [name]],
        value
      )
    end)
  end

  def handle_event(_name, measurements, _metadata, %{type: :summary, label: label} = meta)
      when is_map(measurements) do
    measurements
    |> process_measurements(meta)
    |> Enum.each(fn {name, value} ->
      Summary.observe(
        [name: label, labels: [name]],
        value
      )
    end)
  end

  def handle_event(name, _measurements, _metadata, _config) do
    Logger.error("unhandled metric #{name |> inspect()}")
  end

  defp process_measurements(measurements, %{function: function}) do
    function.(measurements)
  end

  defp process_measurements(measurements, _), do: measurements

  defp process_config(event) do
    name = Keyword.get(event, :name, {:error, "no event name"})
    type = Keyword.get(event, :type, {:error, "no metric type"})
    label = Keyword.get(event, :label, {:error, "no metric label"})
    meta = Keyword.get(event, :meta, %{})

    metric_def = [name, type, label, meta]

    # return error tuple if that is found in metric_def, otherwise return metric_def
    metric_def
    |> Enum.find(metric_def, fn
      {:error, _} -> true
      _ -> false
    end)
  end
end
