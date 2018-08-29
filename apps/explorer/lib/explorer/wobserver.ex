if Code.ensure_loaded(Wobserver) == {:module, Wobserver} do
  defmodule Explorer.Wobserver do
    alias Explorer.{EstimatedCount, Repo}

    def metrics do
      {_, repo_pool_worker_count, _, repo_pool_monitor_count} = :poolboy.status(Repo.Pool)

      %{
        explorer_address_estimated_count: {EstimatedCount.address(), :guage, "Address estimated count."},
        explorer_balance_estimated_count: {EstimatedCount.balance(), :guage, "Balance estimated count."},
        explorer_block_estimated_count: {EstimatedCount.block(), :guage, "Block estimated count."},
        explorer_internal_transaction_estimated_count:
          {EstimatedCount.internal_transaction(), :guage, "Internal Transaction estimated count."},
        explorer_log_estimated_count: {EstimatedCount.log(), :guage, "Log estimated count."},
        explorer_smart_contract_estimated_count:
          {EstimatedCount.smart_contract(), :guage, "Smart Contract estimated count."},
        explorer_token_estimated_count: {EstimatedCount.token(), :guage, "Token estimated count."},
        explorer_token_balance_estimated_count:
          {EstimatedCount.token_balance(), :guage, "Token Balance estimated count."},
        explorer_token_transfer_estimated_count:
          {EstimatedCount.token_transfer(), :guage, "Token Transfer estimated count."},
        explorer_transaction_estimated_count: {EstimatedCount.transaction(), :guage, "Transaction estimated count."},
        explorer_repo_pool_available: {repo_pool_worker_count, :guage, "Explorer.Repo.Pool available workers"},
        explorer_repo_pool_checked_out: {repo_pool_monitor_count, :guage, "Explorer.Repo.Pool checked out workers"}
      }
    end

    def page do
      repo_config = Repo.config()
      repo_pool_size = Keyword.fetch!(repo_config, :pool_size)
      {_, repo_pool_worker_count, _, repo_pool_monitor_count} = :poolboy.status(Repo.Pool)

      %{
        "Estimated Counts" => %{
          "Addresses" => EstimatedCount.address(),
          "Balances" => EstimatedCount.balance(),
          "Blocks" => EstimatedCount.block(),
          "Internal Transactions" => EstimatedCount.internal_transaction(),
          "Logs" => EstimatedCount.log(),
          "Smart Contracts" => EstimatedCount.smart_contract(),
          "Tokens" => EstimatedCount.token(),
          "Token Balances" => EstimatedCount.token_balance(),
          "Token Transfers" => EstimatedCount.token_transfer(),
          "Transactions" => EstimatedCount.transaction()
        },
        "Repo Config" => %{
          "Adapter" => Keyword.fetch!(repo_config, :adapter),
          "Database" => Keyword.fetch!(repo_config, :database),
          # not all configurations will have a hostname
          "Hostname" => repo_config[:hostname],
          "Pool Size" => repo_pool_size,
          "Pool Timeout (ms)" => Keyword.fetch!(repo_config, :pool_timeout),
          "Timeout (ms)" => Keyword.fetch!(repo_config, :timeout)
        },
        "Repo Pool" => %{
          "Usage" => "#{repo_pool_monitor_count} / #{repo_pool_size}",
          "Available" => repo_pool_worker_count,
          "Checked Out" => repo_pool_monitor_count
        }
      }
    end
  end
end
