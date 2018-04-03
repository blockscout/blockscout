defmodule Mix.Tasks.Scrape.Balances do
  @moduledoc "Populate Address balances."

  use Mix.Task

  alias Explorer.Repo
  alias Explorer.SkippedBalances
  alias Explorer.BalanceImporter

  def run([]), do: run(1)

  def run(count) do
    [:postgrex, :ecto, :ethereumex, :tzdata]
    |> Enum.each(&Application.ensure_all_started/1)

    Repo.start_link()
    Exq.start_link(mode: :enqueuer)

    "#{count}"
    |> String.to_integer()
    |> SkippedBalances.fetch()
    |> Flow.from_enumerable()
    |> Flow.map(&BalanceImporter.import/1)
    |> Enum.to_list()
  end
end
