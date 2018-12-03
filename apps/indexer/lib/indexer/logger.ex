defmodule Indexer.Logger do
  @moduledoc """
  Helpers for `Logger`.
  """

  @doc """
  Sets `keyword` in `Logger.metadata/1` around `fun`.
  """
  def metadata(keyword, fun) when is_list(keyword) and is_function(fun, 0) do
    metadata_before = Logger.metadata()

    try do
      Logger.metadata(keyword)
      fun.()
    after
      Logger.reset_metadata(metadata_before)
    end
  end

  @doc """
  The PID and its registered name (if it has one) as `t:iodata/0`.
  """
  def process(pid) when is_pid(pid) do
    prefix = [inspect(pid)]

    {:registered_name, registered_name} = Process.info(pid, :registered_name)

    case registered_name do
      [] -> prefix
      _ -> [prefix, " (", inspect(registered_name), ")"]
    end
  end
end
