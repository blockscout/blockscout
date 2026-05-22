# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.LogHelper do
  @moduledoc """
  Logs helping functions.
  """

  alias Explorer.Chain.Cache.BackgroundMigrations

  @spec primary_key_updated? :: boolean()
  def primary_key_updated? do
    BackgroundMigrations.get_heavy_indexes_update_logs_primary_key_finished()
  end
end
