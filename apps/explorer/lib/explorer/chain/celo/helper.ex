defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  import Explorer.Chain.Cache.CeloCoreContracts, only: [atom_to_contract_name: 0]

  alias Explorer.Chain.Block

  @blocks_per_epoch 17_280
  @core_contract_atoms atom_to_contract_name() |> Map.keys()

  @doc """
  Returns the number of blocks per epoch in the Celo network.
  """
  @spec blocks_per_epoch() :: non_neg_integer()
  def blocks_per_epoch, do: @blocks_per_epoch

  defguard is_epoch_block_number(block_number)
           when is_integer(block_number) and
                  block_number > 0 and
                  rem(block_number, @blocks_per_epoch) == 0

  defguard is_core_contract_atom(atom)
           when atom in @core_contract_atoms

  @doc """
  Validates if a block number is an epoch block number.

  ## Parameters
  - `block_number` (`Block.block_number()`): The block number to validate.

  ## Returns
  - `:ok` if the block number is an epoch block number.
  - `{:error, :not_found}` if the block number is not an epoch block number.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.validate_epoch_block_number(17280)
      :ok

      iex> Explorer.Chain.Celo.Helper.validate_epoch_block_number(17281)
      {:error, :not_found}
  """
  @spec validate_epoch_block_number(Block.block_number()) :: :ok | {:error, :not_found}
  def validate_epoch_block_number(block_number) when is_epoch_block_number(block_number),
    do: :ok

  def validate_epoch_block_number(_block_number), do: {:error, :not_found}

  @doc """
  Checks if a block number belongs to a block that finalized an epoch.

  ## Parameters
  - `block_number` (`Block.block_number()`): The block number to check.

  ## Returns
  - `boolean()`: `true` if the block number is an epoch block number, `false`
    otherwise.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.epoch_block_number?(17280)
      true

      iex> Explorer.Chain.Celo.Helper.epoch_block_number?(17281)
      false
  """
  @spec epoch_block_number?(block_number :: Block.block_number()) :: boolean()
  def epoch_block_number?(block_number) when is_epoch_block_number(block_number), do: true
  def epoch_block_number?(_), do: false

  @doc """
  Converts a block number to an epoch number.

  ## Parameters
  - `block_number` (`Block.block_number()`): The block number to convert.

  ## Returns
  - `non_neg_integer()`: The corresponding epoch number.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.block_number_to_epoch_number(17280)
      1

      iex> Explorer.Chain.Celo.Helper.block_number_to_epoch_number(17281)
      2
  """
  @spec block_number_to_epoch_number(block_number :: Block.block_number()) :: non_neg_integer()
  def block_number_to_epoch_number(block_number) when is_integer(block_number) do
    (block_number / @blocks_per_epoch) |> Float.ceil() |> trunc()
  end

  @doc """
  Convert the burn fraction from FixidityLib value to decimal.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.burn_fraction_decimal(800_000_000_000_000_000_000_000)
      Decimal.new("0.800000000000000000000000")
  """
  @spec burn_fraction_decimal(integer()) :: Decimal.t()
  def burn_fraction_decimal(burn_fraction_fixidity_lib)
      when is_integer(burn_fraction_fixidity_lib) do
    base = Decimal.new(1, 1, 24)
    fraction = Decimal.new(1, burn_fraction_fixidity_lib, 0)
    Decimal.div(fraction, base)
  end

  @doc """
  Checks if a block with given number appeared prior to Celo L2 migration.
  """
  @spec premigration_block_number?(Block.block_number()) :: boolean()
  def premigration_block_number?(block_number) do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      block_number <= l2_migration_block_number
    else
      true
    end
  end
end
