defmodule Indexer.Transform.Blocks.Celo do
  @moduledoc """
  Default block transformer to be used.
  """

  alias Explorer.Celo.AccountReader
  alias Indexer.Transform.Blocks
  alias ExRLP

  @behaviour Blocks

  defp add_gas_limit(block) do
    case AccountReader.block_gas_limit(block.number) do
      {:ok, limit} -> Map.put(block, :gas_limit, limit)
      :error -> block
    end
  end

  defp block_round_number("0x" <> extra_data) do
    extra_data
    |> ExRLP.decode(encoding: :hex)
    |> Enum.at(10)
    |> Enum.at(5)
    |> Enum.at(2)
    |> :binary.decode_unsigned()
  rescue
    _ -> 0
  end

  defp block_round_number(_) do
    0
  end

  @impl Blocks
  def transform(block) when is_map(block) do
    round = block_round_number(block.extra_data)

    block
    |> add_gas_limit()
    |> Map.put(:round, round)
  end
end
