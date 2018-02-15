defmodule Mix.Tasks.Scrape.Receipts do
  @moduledoc "Scrapes blocks from web3"
  use Mix.Task

  alias Explorer.Repo
  alias Explorer.SkippedReceipts
  alias Explorer.ReceiptImporter

  def run([]), do: run(1)
  def run(count) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)
    Repo.start_link()

    "#{count}"
    |> String.to_integer()
    |> SkippedReceipts.first()
    |> Enum.shuffle()
    |> Flow.from_enumerable()
    |> Flow.map(&ReceiptImporter.import/1)
    |> Enum.to_list()
  end
end
