defmodule Mix.Tasks.Scrape.Blocks do
  @moduledoc "Scrapes blocks from web3"
  use Mix.Task
  alias Explorer.Repo
  alias Explorer.SkippedBlocks
  alias Explorer.BlockImporter

  def run([]), do: run(1)

  def run(count) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
    Exq.start_link(mode: :enqueuer)

    "#{count}"
    |> String.to_integer()
    |> SkippedBlocks.first()
    |> Enum.shuffle()
    |> Flow.from_enumerable()
    |> Flow.map(&BlockImporter.download_block/1)
    |> Flow.map(&BlockImporter.import/1)
    |> Enum.to_list()
  end
end
