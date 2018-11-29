defmodule Explorer.Chain.Import.Stage do
  @moduledoc """
  Behaviour used to chunk `changes_list` into multiple `t:Ecto.Multi.t/0`` that can run in separate transactions to
  limit the time that transactions take and how long blocking locks are held in Postgres.
  """

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner

  @typedoc """
  Maps `t:Explorer.Chain.Import.Runner.t/0` callback module to the `t:Explorer.Chain.Import.Runner.changes_list/0` it
  can import.
  """
  @type runner_to_changes_list :: %{Runner.t() => Runner.changes_list()}

  @doc """
  The runners consumed by this stage in `c:multis/0`.  The list should be in the order that the runners are executed.
  """
  @callback runners() :: [Runner.t(), ...]

  @doc """
  Chunks `changes_list` into 1 or more `t:Ecto.Multi.t/0` that can be run in separate transactions.

  The runners used by the stage should be removed from the returned `runner_to_changes_list` map.
  """
  @callback multis(runner_to_changes_list, %{optional(atom()) => term()}) :: {[Multi.t()], runner_to_changes_list}
end
