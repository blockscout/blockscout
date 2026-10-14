defmodule Explorer.Repo.Migrations.WidenWithdrawalsValidatorIndexToBigint do
  @moduledoc """
  Widens `withdrawals.validator_index` from `integer` to `bigint`.

  Since Glamsterdam (EIP-7732, ePBS) builder withdrawals reuse the regular
  `Withdrawal` container with `validator_index = builder_index | 2^40`
  (`BUILDER_INDEX_FLAG`), which does not fit into a 32-bit integer.
  """
  use Ecto.Migration

  def change do
    alter table(:withdrawals) do
      modify(:validator_index, :bigint, null: false, from: {:integer, null: false})
    end
  end
end
