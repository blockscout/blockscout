defmodule Mix.Tasks.Scrape.InternalTransactions do
  @moduledoc "Backfill Internal Transactions via Parity Trace."

  use Mix.Task

  alias Explorer.{InternalTransactionImporter, Repo, SkippedInternalTransactions}

  def run([]), do: run(1)

  def run(count) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()

    "#{count}"
    |> String.to_integer()
    |> SkippedInternalTransactions.first()
    |> Enum.shuffle()
    |> Flow.from_enumerable()
    |> Flow.map(&InternalTransactionImporter.import/1)
    |> Enum.to_list()
  end
end
