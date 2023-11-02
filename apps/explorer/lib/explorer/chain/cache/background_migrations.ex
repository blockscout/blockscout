defmodule Explorer.Chain.Cache.BackgroundMigrations do
  @moduledoc """
  Caches background migrations' status.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :background_migrations_status,
    key: :denormalization_finished

  @dialyzer :no_match

  alias Explorer.TransactionsDenormalizationMigrator

  defp handle_fallback(:denormalization_finished) do
    Task.start(fn ->
      set_denormalization_finished(TransactionsDenormalizationMigrator.migration_finished?())
    end)

    {:return, false}
  end
end
