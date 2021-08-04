defmodule Indexer.LoggerBackend do
  @moduledoc """
  Custom logger backend that increments the error metric whenever Logger.error is called.
  """
  @behaviour :gen_event

  defstruct level: :error, metadata: [], excluded_domains: [:cowboy], capture_log_messages: false

  def init(__MODULE__) do
    config = Application.get_env(:logger, __MODULE__, [])
    {:ok, struct(%__MODULE__{}, config)}
  end

  def init({__MODULE__, opts}) when is_list(opts) do
    config =
      :logger
      |> Application.get_env(__MODULE__, [])
      |> Keyword.merge(opts)

    {:ok, struct(%__MODULE__{}, config)}
  end

  def handle_call({:configure, options}, state) do
    config =
      :logger
      |> Application.get_env(__MODULE__, [])
      |> Keyword.merge(options)

    Application.put_env(:logger, __MODULE__, config)
    {:ok, :ok, struct(state, config)}
  end

  def handle_event({_level, gl, {Logger, _, _, _}}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, _msg, _ts, _meta}}, state) do
    if Logger.compare_levels(level, state.level) != :lt do
      :telemetry.execute([:indexer, :generics, :error], %{count: 1})
    end

    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
