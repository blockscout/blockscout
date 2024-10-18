defmodule Explorer.Chain.Cache.BackgroundMigrations do
  @moduledoc """
  Caches background migrations' status.
  """

  require Logger

  use Explorer.Chain.MapCache,
    name: :background_migrations_status,
    key: :transactions_denormalization_finished,
    key: :tb_token_type_finished,
    key: :ctb_token_type_finished,
    key: :tt_denormalization_finished,
    key: :sanitize_duplicated_log_index_logs_finished

  @dialyzer :no_match

  alias Explorer.Migrator.{
    AddressCurrentTokenBalanceTokenType,
    AddressTokenBalanceTokenType,
    SanitizeDuplicatedLogIndexLogs,
    TokenTransferTokenType,
    TransactionsDenormalization
  }

  defp handle_fallback(:transactions_denormalization_finished) do
    Task.start_link(fn ->
      set_transactions_denormalization_finished(TransactionsDenormalization.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:tb_token_type_finished) do
    Task.start_link(fn ->
      set_tb_token_type_finished(AddressTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:ctb_token_type_finished) do
    Task.start_link(fn ->
      set_ctb_token_type_finished(AddressCurrentTokenBalanceTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:tt_denormalization_finished) do
    Task.start_link(fn ->
      set_tt_denormalization_finished(TokenTransferTokenType.migration_finished?())
    end)

    {:return, false}
  end

  defp handle_fallback(:sanitize_duplicated_log_index_logs_finished) do
    Task.start_link(fn ->
      set_sanitize_duplicated_log_index_logs_finished(SanitizeDuplicatedLogIndexLogs.migration_finished?())
    end)

    {:return, false}
  end
end
