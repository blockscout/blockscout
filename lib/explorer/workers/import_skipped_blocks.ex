defmodule Explorer.Workers.ImportSkippedBlocks do
  alias Explorer.SkippedBlocks
  alias Explorer.Workers.ImportBlock

  @moduledoc "Imports skipped blocks."

  def perform, do: perform(1)
  def perform(count) do
    count |> SkippedBlocks.first |> Enum.map(&ImportBlock.perform_later/1)
  end

  def perform_later, do: perform_later(1)
  def perform_later(count) do
    Exq.enqueue(Exq.Enqueuer, "default", __MODULE__, [count])
  end
end
