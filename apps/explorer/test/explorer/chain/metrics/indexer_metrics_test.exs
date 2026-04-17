defmodule Explorer.Chain.Metrics.Queries.IndexerMetricsTest do
  use Explorer.DataCase, async: false

  import Explorer.Factory

  alias Explorer.Chain.Metrics.Queries.IndexerMetrics

  describe "missing_blocks_count/0" do
    test "counts only within configured ranges and latest tail" do
      previous_block_ranges = Application.get_env(:indexer, :block_ranges)
      on_exit(fn -> Application.put_env(:indexer, :block_ranges, previous_block_ranges) end)

      Application.put_env(:indexer, :block_ranges, "1..3,5..latest")

      Enum.each([1, 2, 3, 5, 7, 8], fn number ->
        insert(:block, number: number, consensus: true)
      end)

      assert IndexerMetrics.missing_blocks_count() == 1
    end

    test "counts only within finite ranges" do
      previous_block_ranges = Application.get_env(:indexer, :block_ranges)
      on_exit(fn -> Application.put_env(:indexer, :block_ranges, previous_block_ranges) end)

      Application.put_env(:indexer, :block_ranges, "10..12,20..22")

      Enum.each([10, 11, 12, 20, 22], fn number ->
        insert(:block, number: number, consensus: true)
      end)

      assert IndexerMetrics.missing_blocks_count() == 1
    end
  end

  describe "missing_internal_transactions_count/0" do
    test "counts pending block operations when pending_operations_type is blocks" do
      previous_explorer_config = Application.get_env(:explorer, :json_rpc_named_arguments)
      previous_geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      previous_trace_first_block = Application.get_env(:indexer, :trace_first_block)

      on_exit(fn ->
        Application.put_env(:explorer, :json_rpc_named_arguments, previous_explorer_config)
        Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, previous_geth_config)
        Application.put_env(:indexer, :trace_first_block, previous_trace_first_block)
      end)

      # Set configuration to use "blocks" mode (non-Geth or Geth with block_traceable)
      Application.put_env(:explorer, :json_rpc_named_arguments, variant: EthereumJSONRPC.Nethermind)

      block1 = insert(:block)
      block2 = insert(:block)
      block3 = insert(:block)

      insert(:pending_block_operation, block_hash: block1.hash, block_number: block1.number)
      insert(:pending_block_operation, block_hash: block2.hash, block_number: block2.number)
      insert(:pending_block_operation, block_hash: block3.hash, block_number: block3.number)

      assert IndexerMetrics.missing_internal_transactions_count() == 3
    end

    test "respects trace_first_block when counting pending block operations" do
      previous_explorer_config = Application.get_env(:explorer, :json_rpc_named_arguments)
      previous_geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      previous_trace_first_block = Application.get_env(:indexer, :trace_first_block)

      on_exit(fn ->
        Application.put_env(:explorer, :json_rpc_named_arguments, previous_explorer_config)
        Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, previous_geth_config)
        Application.put_env(:indexer, :trace_first_block, previous_trace_first_block)
      end)

      Application.put_env(:explorer, :json_rpc_named_arguments, variant: EthereumJSONRPC.Nethermind)
      Application.put_env(:indexer, :trace_first_block, 10)

      block1 = insert(:block, number: 8)
      block2 = insert(:block, number: 10)
      block3 = insert(:block, number: 12)

      insert(:pending_block_operation, block_hash: block1.hash, block_number: block1.number)
      insert(:pending_block_operation, block_hash: block2.hash, block_number: block2.number)
      insert(:pending_block_operation, block_hash: block3.hash, block_number: block3.number)

      assert IndexerMetrics.missing_internal_transactions_count() == 2
    end

    test "counts pending transaction operations when pending_operations_type is transactions" do
      previous_explorer_config = Application.get_env(:explorer, :json_rpc_named_arguments)
      previous_geth_config = Application.get_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth)
      previous_trace_first_block = Application.get_env(:indexer, :trace_first_block)

      on_exit(fn ->
        Application.put_env(:explorer, :json_rpc_named_arguments, previous_explorer_config)
        Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, previous_geth_config)
        Application.put_env(:indexer, :trace_first_block, previous_trace_first_block)
      end)

      # Set configuration to use "transactions" mode (Geth with block_traceable? = false)
      Application.put_env(:explorer, :json_rpc_named_arguments, variant: EthereumJSONRPC.Geth)
      Application.put_env(:ethereum_jsonrpc, EthereumJSONRPC.Geth, block_traceable?: false)

      transaction1 = insert(:transaction)
      transaction2 = insert(:transaction)

      insert(:pending_transaction_operation, transaction_hash: transaction1.hash)
      insert(:pending_transaction_operation, transaction_hash: transaction2.hash)

      assert IndexerMetrics.missing_internal_transactions_count() == 2
    end
  end

  describe "missing_archival_token_balances_count/0" do
    test "returns 0 when archival token balances fetcher is disabled" do
      previous_config =
        Application.get_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, previous_config)
      end)

      Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, disabled?: true)

      insert(:token_balance, value_fetched_at: nil)
      insert(:token_balance, value_fetched_at: nil)

      assert IndexerMetrics.missing_archival_token_balances_count() == 0
    end

    test "counts token balances with missing values when fetcher is enabled" do
      previous_config =
        Application.get_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, previous_config)
      end)

      Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, disabled?: false)

      insert(:token_balance, value_fetched_at: nil)
      insert(:token_balance, value_fetched_at: nil)
      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      assert IndexerMetrics.missing_archival_token_balances_count() == 2
    end

    test "returns 0 when all token balances are fetched" do
      previous_config =
        Application.get_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor)

      on_exit(fn ->
        Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, previous_config)
      end)

      Application.put_env(:indexer, Indexer.Fetcher.TokenBalance.Historical.Supervisor, disabled?: false)

      insert(:token_balance, value_fetched_at: DateTime.utc_now())
      insert(:token_balance, value_fetched_at: DateTime.utc_now())

      assert IndexerMetrics.missing_archival_token_balances_count() == 0
    end
  end

  describe "multichain_search_db_export_balances_queue_count/0" do
    test "returns 0 when multichain search is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, service_url: nil)

      insert(:multichain_search_db_export_balances_queue)
      insert(:multichain_search_db_export_balances_queue)

      assert IndexerMetrics.multichain_search_db_export_balances_queue_count() == 0
    end

    test "returns 0 when balances export queue supervisor is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor, disabled?: true)

      insert(:multichain_search_db_export_balances_queue)
      insert(:multichain_search_db_export_balances_queue)

      assert IndexerMetrics.multichain_search_db_export_balances_queue_count() == 0
    end

    test "counts queue entries when both enabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor, disabled?: false)

      insert(:multichain_search_db_export_balances_queue)
      insert(:multichain_search_db_export_balances_queue)

      assert IndexerMetrics.multichain_search_db_export_balances_queue_count() == 2
    end
  end

  describe "multichain_search_db_export_counters_queue_count/0" do
    test "returns 0 when multichain search is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, service_url: nil)

      insert(:multichain_search_db_export_counters_queue)

      assert IndexerMetrics.multichain_search_db_export_counters_queue_count() == 0
    end

    test "returns 0 when counters export queue supervisor is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor, disabled?: true)

      insert(:multichain_search_db_export_counters_queue)

      assert IndexerMetrics.multichain_search_db_export_counters_queue_count() == 0
    end

    test "counts queue entries when both enabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor, disabled?: false)

      insert(:multichain_search_db_export_counters_queue)

      assert IndexerMetrics.multichain_search_db_export_counters_queue_count() == 1
    end
  end

  describe "multichain_search_db_export_token_info_queue_count/0" do
    test "returns 0 when multichain search is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, service_url: nil)

      insert(:multichain_search_db_export_token_info_queue)

      assert IndexerMetrics.multichain_search_db_export_token_info_queue_count() == 0
    end

    test "returns 0 when token info export queue supervisor is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor, disabled?: true)

      insert(:multichain_search_db_export_token_info_queue)

      assert IndexerMetrics.multichain_search_db_export_token_info_queue_count() == 0
    end

    test "counts queue entries when both enabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor,
        disabled?: false
      )

      insert(:multichain_search_db_export_token_info_queue)

      assert IndexerMetrics.multichain_search_db_export_token_info_queue_count() == 1
    end
  end

  describe "multichain_search_db_main_export_queue_count/0" do
    test "returns 0 when multichain search is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, service_url: nil)

      insert(:multichain_search_db_main_export_queue)

      assert IndexerMetrics.multichain_search_db_main_export_queue_count() == 0
    end

    test "returns 0 when main export queue supervisor is disabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor, disabled?: true)

      insert(:multichain_search_db_main_export_queue)

      assert IndexerMetrics.multichain_search_db_main_export_queue_count() == 0
    end

    test "counts queue entries when both enabled" do
      previous_enabled =
        Application.get_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch)

      previous_supervisor_config =
        Application.get_env(:indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor)

      on_exit(fn ->
        Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch, previous_enabled)

        Application.put_env(
          :indexer,
          Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor,
          previous_supervisor_config
        )
      end)

      Application.put_env(:explorer, Explorer.MicroserviceInterfaces.MultichainSearch,
        service_url: "http://localhost:8080"
      )

      Application.put_env(:indexer, Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor, disabled?: false)

      insert(:multichain_search_db_main_export_queue)

      assert IndexerMetrics.multichain_search_db_main_export_queue_count() == 1
    end
  end
end
