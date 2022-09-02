defmodule Indexer.Fetcher.Util do
  @moduledoc """
  Some shared code
  """

  @defaults [
    flush_interval: 300,
    max_batch_size: 100,
    max_concurrency: 10,
    state: {0, []}
  ]

  def default_child_spec(init_options, gen_server_options, module) do
    merged_init_opts =
      @defaults
      |> Keyword.merge(init_options)
      |> Keyword.put(:task_supervisor, Module.concat(module, "TaskSupervisor"))

    Supervisor.child_spec({Indexer.BufferedTask, [{module, merged_init_opts}, gen_server_options]}, id: module)
  end
end
