defmodule Mix.Tasks.Backfill do
  use Mix.Task
  alias Explorer.SkippedBlocks

  @shortdoc "Backfill blocks from the chain."
  @moduledoc false

  def run(_) do
    Mix.Task.run("app.start")
    SkippedBlocks.fetch()
  end
end
