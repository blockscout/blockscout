defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  import Explorer.Chain.Cache.CeloCoreContracts, only: [atom_to_contract_name: 0]

  alias Explorer.Chain.Block

  @burn_address_hash_string "0x000000000000000000000000000000000000dead"

  def burn_address_hash_string, do: @burn_address_hash_string

  @blocks_per_epoch 17_280

  @core_contract_atoms atom_to_contract_name() |> Map.keys()

  def blocks_per_epoch, do: @blocks_per_epoch

  defguard is_epoch_block_number(block_number)
           when is_integer(block_number) and
                  block_number >= 0 and
                  rem(block_number, @blocks_per_epoch) == 0

  defguard is_core_contract_atom(atom)
           when atom in @core_contract_atoms

  @spec epoch_block_number?(block_number :: Block.block_number()) :: boolean
  def epoch_block_number?(block_number)
      when is_epoch_block_number(block_number),
      do: true

  def epoch_block_number?(_), do: false

  @spec block_number_to_epoch_number(block_number :: Block.block_number()) :: non_neg_integer
  def block_number_to_epoch_number(block_number) when is_integer(block_number) do
    (block_number / @blocks_per_epoch) |> Float.ceil() |> trunc()
  end

  def validate_epoch_block_number(block_number)
      when is_epoch_block_number(block_number),
      do: :ok

  def validate_epoch_block_number(_block_number),
    do: {:error, :not_found}
end
