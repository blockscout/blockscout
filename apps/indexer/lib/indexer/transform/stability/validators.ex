defmodule Indexer.Transform.Stability.Validators do
  @moduledoc """
  Helper functions for transforming blocks into stability validator counter updates.
  """

  require Logger

  @doc """
  Returns a list of validator counter updates given a list of blocks.
  Only processes blocks for stability chain type.
  """
  def parse(blocks) do
    chain_type = Application.get_env(:explorer, :chain_type)

    if chain_type == :stability do
      do_parse(blocks)
    else
      []
    end
  end

  defp do_parse(blocks) when is_list(blocks) do
    blocks
    |> Enum.filter(&(&1[:miner_hash] != nil))
    |> Enum.group_by(& &1[:miner_hash])
    |> Enum.map(fn {miner_hash, validator_blocks} ->
      %{
        address_hash: miner_hash,
        blocks_validated: length(validator_blocks)
      }
    end)
  end

  defp do_parse(_), do: []
end
