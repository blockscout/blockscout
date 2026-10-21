# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.QuerySources do
  @moduledoc """
  Records the `source` tables of the queries issued by a piece of code.
  """

  @query_events [[:explorer, :repo, :query], [:explorer, :repo, :replica1, :query]]

  @doc """
  Runs `fun` and returns its result with the `source` tables of every query
  issued meanwhile by the calling process or on its behalf, such as by the tasks
  Ecto runs the preloads of the same level in.
  """
  @spec with_query_sources((-> result)) :: {result, [String.t() | nil]} when result: any()
  def with_query_sources(fun) do
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(handler_id, @query_events, &__MODULE__.handle_query_event/4, self())

    try do
      {fun.(), collect_query_sources([])}
    after
      :telemetry.detach(handler_id)
    end
  end

  @doc false
  def handle_query_event(_event, _measurements, %{source: source}, caller) do
    if caller in [self() | Process.get(:"$callers", [])], do: send(caller, {:query_source, source})
  end

  defp collect_query_sources(acc) do
    receive do
      {:query_source, source} -> collect_query_sources([source | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
