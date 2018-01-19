defmodule Mix.Tasks.Scrape do
  use Mix.Task
  alias Explorer.LatestBlock

  @shortdoc "Scrape the blockchain."
  @moduledoc false

  def run(_) do
    Mix.Task.run "app.start"
    LatestBlock.fetch()
  end
end
