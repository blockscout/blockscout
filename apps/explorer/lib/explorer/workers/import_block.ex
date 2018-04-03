defmodule Explorer.Workers.ImportBlock do
  @moduledoc "Imports blocks by web3 conventions."

  import Ethereumex.HttpClient, only: [eth_block_number: 0]

  alias Explorer.BlockImporter

  @dialyzer {:nowarn_function, perform: 1}
  def perform("latest") do
    case eth_block_number() do
      {:ok, number} -> perform_later(number)
      _ -> nil
    end
  end

  @dialyzer {:nowarn_function, perform: 1}
  def perform(number), do: BlockImporter.import("#{number}")

  def perform_later("0x" <> number) when is_binary(number) do
    number |> String.to_integer(16) |> perform_later()
  end

  def perform_later(number) do
    Exq.enqueue(Exq.Enqueuer, "blocks", __MODULE__, [number])
  end
end
