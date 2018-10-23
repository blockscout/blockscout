defmodule Indexer.Logger do
  @moduledoc """
  Helpers for formatting `Logger` data as `t:iodata/0`.
  """

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
