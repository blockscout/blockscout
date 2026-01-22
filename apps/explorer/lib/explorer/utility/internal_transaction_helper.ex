defmodule Explorer.Utility.InternalTransactionHelper do
  @moduledoc """
  Internal transactions helping functions.
  """

  alias Explorer.Chain.Cache.BackgroundMigrations

  @spec primary_key_updated? :: boolean()
  def primary_key_updated? do
    BackgroundMigrations.get_heavy_indexes_update_internal_transactions_primary_key_finished()
  end
end
