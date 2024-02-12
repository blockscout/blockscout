defmodule Explorer.Chain.Cache.BackgroundMigrations do
  @moduledoc """
  Caches background migrations' status.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :background_migrations_status,
    key: :denormalization_finished,
    key: :tb_token_type_finished,
    key: :ctb_token_type_finished

  @dialyzer :no_match

  alias Explorer.Migrator.{
    AddressCurrentTokenBalanceTokenType,
    AddressTokenBalanceTokenType,
    TransactionsDenormalization
  }

  defp handle_fallback(:denormalization_finished) do
    Task.start(fn ->
      set_denormalization_finished(TransactionsDenormalization.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:tb_token_type_finished) do
    Task.start(fn ->
      set_tb_token_type_finished(AddressTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:ctb_token_type_finished) do
    Task.start(fn ->
      set_ctb_token_type_finished(AddressCurrentTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end
end
