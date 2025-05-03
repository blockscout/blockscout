defmodule Indexer.Transform.Celo.L1Epochs do
  use Utils.RuntimeEnvHelper,
    chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.{Block, Celo.Epoch}
  alias Explorer.Chain.Celo.Helper

  @spec parse([Block.t()]) :: [Epoch.t()]
  def parse(blocks) do
    if chain_type() == :celo do
      do_parse(blocks)
    else
      []
    end
  end

  defp do_parse(blocks) do
    blocks
    |> Enum.filter(fn %{number: number} ->
      Helper.pre_migration_block_number?(number) and
        Helper.epoch_block_number?(number)
    end)
    |> Enum.map(fn block ->
      epoch_number =
        Helper.block_number_to_epoch_number(block.number)

      {start_block_number, end_block_number} =
        Helper.epoch_number_to_block_range(epoch_number)

      %{
        number: epoch_number,
        start_block_number: start_block_number,
        end_block_number: end_block_number,
        start_processing_block_hash: block.hash,
        end_processing_block_hash: block.hash
      }
    end)
  end
end
