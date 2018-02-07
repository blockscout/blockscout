defmodule Explorer.Workers.ImportBlock do
  alias Explorer.BlockImporter

  @moduledoc "Imports blocks by web3 conventions."

  @dialyzer {:nowarn_function, perform: 1}
  def perform(number) do
    BlockImporter.import("#{number}")
  end

  @dialyzer {:nowarn_function, perform: 0}
  def perform, do: perform("latest")

  def perform_later("latest") do
    Exq.enqueue(Exq.Enqueuer, "blocks", __MODULE__, ["latest"], max_retries: 0)
  end

  def perform_later(number) do
    Exq.enqueue(Exq.Enqueuer, "blocks", __MODULE__, [number])
  end
end
