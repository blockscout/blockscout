defmodule Explorer.Chain.Celo.Helper do
  @moduledoc """
  Common helper functions for Celo.
  """

  alias Explorer.Chain.Block

  @blocks_per_epoch 17_280

  @doc """
  Checks if a block number belongs to a block that finalized an L1-era epoch.

  This function should only be used for pre-L2 migration blocks, as the concept
  of epoch blocks no longer exists after L2 migration.

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
  def epoch_block_number?(block_number)
      when is_integer(block_number) and
             block_number > 0 and
             rem(block_number, @blocks_per_epoch) == 0,
      do: true

  def epoch_block_number?(_), do: false

  @doc """
  Converts a block number to an epoch number.

  ## Parameters
  - `block_number` (`Block.block_number()`): The block number to convert.

  ## Returns
  - `non_neg_integer()`: The corresponding epoch number.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.block_number_to_epoch_number(17279)
      1

      iex> Explorer.Chain.Celo.Helper.block_number_to_epoch_number(17280)
      2

      iex> Explorer.Chain.Celo.Helper.block_number_to_epoch_number(17281)
      2
  """
  @spec block_number_to_epoch_number(block_number :: Block.block_number()) :: non_neg_integer()
  def block_number_to_epoch_number(block_number) when is_integer(block_number) do
    (block_number / @blocks_per_epoch) |> Float.floor() |> trunc() |> Kernel.+(1)
  end

  @doc """
  Converts an epoch number to a block range for L1-era epochs.

  This function should only be used for pre-L2 migration epochs, as epoch block
  ranges are deterministic only in L1 era.

  ## Parameters
  - `epoch_number` (`non_neg_integer()`): The epoch number to convert.

  ## Returns
  - `{Block.block_number(), Block.block_number()}`: A tuple containing the start
    and end block numbers of the epoch.

  ## Examples

      iex> Explorer.Chain.Celo.Helper.epoch_number_to_block_range(1)
      {0, 17279}

      iex> Explorer.Chain.Celo.Helper.epoch_number_to_block_range(2)
      {17280, 34559}
  """
  @spec epoch_number_to_block_range(epoch_number :: non_neg_integer()) ::
          {Block.block_number(), Block.block_number()}
  def epoch_number_to_block_range(epoch_number)
      when is_integer(epoch_number) and epoch_number > 0 do
    start_block = (epoch_number - 1) * @blocks_per_epoch
    end_block = epoch_number * @blocks_per_epoch - 1

    {start_block, end_block}
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
  @spec pre_migration_block_number?(Block.block_number()) :: boolean()
  def pre_migration_block_number?(block_number) do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      block_number < l2_migration_block_number
    else
      true
    end
  end

  @doc """
  Checks if an epoch number is prior to Celo L2 migration.
  """
  @spec pre_migration_epoch_number?(non_neg_integer()) :: boolean()
  def pre_migration_epoch_number?(epoch_number) do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      l2_migration_epoch_number = l2_migration_block_number |> block_number_to_epoch_number()
      epoch_number < l2_migration_epoch_number
    else
      true
    end
  end
end
