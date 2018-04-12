defmodule Explorer.ExqNodeIdentifier do
  @behaviour Exq.NodeIdentifier.Behaviour
  @moduledoc "Configure Exq with the current dyno name"
  def node_id, do: System.get_env("DYNO")
end
