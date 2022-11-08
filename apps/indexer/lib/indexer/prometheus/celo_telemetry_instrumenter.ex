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
      [name, type, metric_id, meta] ->
        attach_event(name, type, metric_id, meta)

      {:error, msg} ->
        Logger.error("Error configuring event #{inspect(event_config)}: #{msg}")
    end
  end

  def attach_event(name, :summary, metric_id, %{metric_labels: metric_labels, help: help} = meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Summary.declare(
      name: metric_id,
      labels: metric_labels,
      help: help
    )

    handler_meta = meta |> Map.merge(%{type: :summary, metric_id: metric_id})

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, handler_meta)
  end

  def attach_event(name, :counter, metric_id, %{metric_labels: metric_labels, help: help} = meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Counter.declare(
      name: metric_id,
      labels: metric_labels,
      help: help
    )

    handler_meta = meta |> Map.merge(%{type: :counter, metric_id: metric_id})

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, handler_meta)
  end

  def attach_event(name, :counter, metric_id, %{help: help} = meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Counter.declare(
      name: metric_id,
      help: help
    )

    handler_meta = meta |> Map.merge(%{type: :counter, metric_id: metric_id})

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, handler_meta)
  end

  def attach_event(name, :histogram, metric_id, %{buckets: buckets, metric_labels: metric_labels, help: help} = _meta) do
    Logger.info("Attach event #{name |> inspect()}")

    Histogram.new(
      name: metric_id,
      buckets: buckets,
      duration_unit: false,
      labels: metric_labels,
      help: help
    )

    :telemetry.attach(handler_id(name), name, &__MODULE__.handle_event/4, %{type: :histogram, metric_id: metric_id})
  end

  def attach_event(name, _type, _label, _meta), do: Logger.info("Unhandled metric attach request: #{name |> inspect()}")

  defp handler_id(event_name), do: "event_handler_id_#{event_name |> Enum.join() |> to_string()}"

  ## Handle events
  def handle_event(_event_name, _measurements, _metadata, %{type: :counter, metric_id: metric_id}) do
    Counter.inc(name: metric_id)
  end

  def handle_event(_event_name, measurements, event_metadata, %{type: :histogram, metric_id: metric_id} = def_meta)
      when is_map(measurements) do
    measurements
    |> process_measurements(def_meta, event_metadata)
    |> Enum.each(fn {name, value} ->
      Histogram.observe(
        [name: metric_id, labels: [name]],
        value
      )
    end)
  end

  def handle_event(_event_name, measurements, event_metadata, %{type: :summary, metric_id: metric_id} = def_meta)
      when is_map(measurements) do
    measurements
    |> process_measurements(def_meta, event_metadata)
    |> Enum.each(fn {name, value} ->
      Summary.observe(
        [name: metric_id, labels: [name]],
        value
      )
    end)
  end

  def handle_event(handler_id, _measurements, _metadata, _config) do
    Logger.error("unhandled metric #{handler_id |> inspect()}")
  end

  defp process_measurements(measurements, %{function: function} = event_definition_meta, event_meta) do
    meta = Map.merge(event_definition_meta, event_meta)
    function.(measurements, meta)
  end

  defp process_measurements(measurements, _, _), do: measurements

  defp process_config(event) do
    name = Keyword.get(event, :name, {:error, "no event name"})
    type = Keyword.get(event, :type, {:error, "no metric type"})
    metric_id = Keyword.get(event, :metric_id, {:error, "no metric_id"})
    meta = Keyword.get(event, :meta, %{})

    metric_def = [name, type, metric_id, meta]

    # return error tuple if that is found in metric_def, otherwise return metric_def
    metric_def
    |> Enum.find(metric_def, fn
      {:error, _} -> true
      _ -> false
    end)
  end
end
