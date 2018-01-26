defmodule Mix.Tasks.Scrape do
  use Mix.Task
  alias Explorer.LatestBlock

  @shortdoc "Scrape the blockchain."
  @moduledoc false

  @dialyzer {:nowarn_function, run: 1}
  def run(_) do
    Mix.Task.run("app.start")
    LatestBlock.fetch()
  end
end
