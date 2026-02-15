defmodule Explorer.Chain.Metrics.Queries.IndexerMetrics do
  @moduledoc """
  Module for DB queries to get indexer health metrics
  """

  import Ecto.Query
  alias Ecto.Adapters.SQL
  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Chain.MultichainSearchDb.BalancesExportQueue, as: MultichainSearchDbBalancesExportQueue
  alias Explorer.Chain.MultichainSearchDb.CountersExportQueue, as: MultichainSearchDbCountersExportQueue
  alias Explorer.Chain.MultichainSearchDb.MainExportQueue, as: MultichainSearchDbMainExportQueue
  alias Explorer.Chain.MultichainSearchDb.TokenInfoExportQueue, as: MultichainSearchDbTokenInfoExportQueue
  alias Explorer.Chain.{PendingBlockOperation, PendingOperationsHelper, PendingTransactionOperation}
  alias Explorer.Chain.Token.Instance
  alias Explorer.MicroserviceInterfaces.MultichainSearch
  alias Explorer.Repo

  @doc """
  Query to get the number of missing block numbers in the DB
  """
  # sobelow_skip ["SQL"]
  @spec missing_blocks_count() :: integer()
  def missing_blocks_count do
    block_ranges = RangesHelper.get_block_ranges()

    if block_ranges == [] do
      0
    else
      {sql_parts, params} =
        Enum.reduce(block_ranges, {[], []}, fn
          first..last//_, {parts, acc_params} ->
            from = min(first, last)
            to = max(first, last)
            param_index_from = length(acc_params) + 1
            param_index_to = length(acc_params) + 2

            part = """
            SELECT COUNT(*) AS missing_count
            FROM generate_series($#{param_index_from}::bigint, $#{param_index_to}::bigint) AS num(number)
            WHERE NOT EXISTS (
              SELECT 1 FROM blocks b WHERE b.number = num.number AND b.consensus
            )
            """

            {[part | parts], [to, from | acc_params]}

          start_from, {parts, acc_params} ->
            param_index = length(acc_params) + 1

            part = """
            SELECT COUNT(*) AS missing_count
            FROM generate_series(
              $#{param_index}::bigint,
              (SELECT COALESCE(MAX(number), $#{param_index}) FROM blocks)::bigint
            ) AS num(number)
            WHERE NOT EXISTS (
              SELECT 1 FROM blocks b WHERE b.number = num.number AND b.consensus
            )
            """

            {[part | parts], [start_from | acc_params]}
        end)

      sql_string =
        sql_parts
        |> Enum.reverse()
        |> Enum.join("\n  UNION ALL\n  ")
        |> then(&"SELECT SUM(missing_count) AS missing_blocks_count FROM (\n  #{&1}\n) AS counts(missing_count)")

      case SQL.query(Repo, sql_string, Enum.reverse(params), timeout: :infinity) do
        {:ok, %Postgrex.Result{command: :select, columns: ["missing_blocks_count"], rows: [[missing_blocks_count]]}} ->
          normalize_missing_blocks_count(missing_blocks_count)

        _ ->
          0
      end
    end
  end

  defp normalize_missing_blocks_count(nil), do: 0
  defp normalize_missing_blocks_count(%Decimal{} = value), do: Decimal.to_integer(value)
  defp normalize_missing_blocks_count(value), do: value

  @doc """
  Query to get the number of missing internal transactions in the DB
  """
  @spec missing_internal_transactions_count() :: integer()
  def missing_internal_transactions_count do
    case PendingOperationsHelper.pending_operations_type() do
      "blocks" -> Repo.aggregate(PendingBlockOperation, :count, :block_hash, timeout: :infinity)
      "transactions" -> Repo.aggregate(PendingTransactionOperation, :count, :transaction_hash, timeout: :infinity)
    end
  end

  @doc """
  Query to get the count of current token balances with missing values
  """
  # sobelow_skip ["SQL"]
  @spec missing_current_token_balances_count() :: integer()
  def missing_current_token_balances_count do
    sql_string =
      """
      SELECT COUNT(1) as missing_current_token_balances_count
      FROM address_current_token_balances ctb
      WHERE (ctb.value_fetched_at is NULL OR ctb.value is NULL)
      AND NOT EXISTS(
        SELECT 1 FROM address_token_balances tb
        WHERE tb.address_hash = ctb.address_hash
        AND tb.token_contract_address_hash = ctb.token_contract_address_hash
        AND tb.retries_count is not null
      );
      """

    case SQL.query(Repo, sql_string, [], timeout: :infinity) do
      {:ok,
       %Postgrex.Result{
         command: :select,
         columns: ["missing_current_token_balances_count"],
         rows: [[missing_current_token_balances_count]]
       }} ->
        missing_current_token_balances_count

      _ ->
        0
    end
  end

  @doc """
  Query to get the count of archival token balances with missing values
  """
  @spec missing_archival_token_balances_count() :: integer()
  def missing_archival_token_balances_count do
    if archival_token_balances_fetcher_disabled?() do
      0
    else
      query =
        from(
          token_balance in TokenBalance,
          where: is_nil(token_balance.value_fetched_at)
        )

      query
      |> Repo.aggregate(:count, :id, timeout: :infinity)
    end
  end

  defp archival_token_balances_fetcher_disabled? do
    :indexer
    |> Application.get_env(Indexer.Fetcher.TokenBalance.Historical.Supervisor, [])
    |> Keyword.get(:disabled?)
  end

  @doc """
  Query to get the count of token instances with failed metadata fetches
  """
  @spec failed_token_instances_metadata_count() :: integer()
  def failed_token_instances_metadata_count do
    query =
      from(
        token_instance in Instance,
        where: not is_nil(token_instance.error)
      )

    query
    |> Repo.aggregate(:count, :token_id, timeout: :infinity)
  end

  @doc """
  Query to get the count of unfetched token instances
  """
  # sobelow_skip ["SQL"]
  @spec unfetched_token_instances_count() :: integer()
  def unfetched_token_instances_count do
    sql_string =
      """
      SELECT COUNT(1) AS unfetched_token_instances_count
      FROM (
        SELECT DISTINCT ON (s0."contract_address_hash", s0."token_id") s0."contract_address_hash", s0."token_id"
        FROM (
          SELECT ss0."token_contract_address_hash" AS "contract_address_hash", ss0."token_id" AS "token_id"
          FROM (
            SELECT sst0."token_contract_address_hash" AS "token_contract_address_hash", unnest(sst0."token_ids") AS "token_id"
            FROM "token_transfers" AS sst0) AS ss0 INNER JOIN (
              SELECT sst0."contract_address_hash" AS "contract_address_hash"
              FROM "tokens" AS sst0
              WHERE ((sst0."type" = 'ERC-1155') OR (sst0."type" = 'ERC-721'))
            ) AS ss1 ON ss1."contract_address_hash" = ss0."token_contract_address_hash"
          LEFT OUTER JOIN "token_instances" AS st2 ON (ss0."token_contract_address_hash" = st2."token_contract_address_hash")
          AND (ss0."token_id" = st2."token_id")
          WHERE (st2."token_id" IS NULL)
        ) AS s0
      ) AS a;
      """

    case SQL.query(Repo, sql_string, [], timeout: :infinity) do
      {:ok,
       %Postgrex.Result{
         command: :select,
         columns: ["unfetched_token_instances_count"],
         rows: [[unfetched_token_instances_count]]
       }} ->
        unfetched_token_instances_count

      _ ->
        0
    end
  end

  @doc """
  Query to get the count of token instances not uploaded to CDN
  """
  # sobelow_skip ["SQL"]
  @spec token_instances_not_uploaded_to_cdn_count() :: integer()
  def token_instances_not_uploaded_to_cdn_count do
    sql_string =
      """
      SELECT COUNT(1) AS token_instances_not_uploaded_to_cdn_count
      FROM token_instances WHERE metadata IS NOT NULL AND thumbnails IS NULL AND cdn_upload_error IS NULL;
      """

    case SQL.query(Repo, sql_string, [], timeout: :infinity) do
      {:ok,
       %Postgrex.Result{
         command: :select,
         columns: ["token_instances_not_uploaded_to_cdn_count"],
         rows: [[token_instances_not_uploaded_to_cdn_count]]
       }} ->
        token_instances_not_uploaded_to_cdn_count

      _ ->
        0
    end
  end

  @doc """
  Query to get the count of multichain_search_db_export_balances_queue entries
  """
  @spec multichain_search_db_export_balances_queue_count() :: integer()
  def multichain_search_db_export_balances_queue_count do
    if multichain_search_enabled?() and not multichain_search_balances_export_queue_disabled?() do
      Repo.aggregate(MultichainSearchDbBalancesExportQueue, :count, :id, timeout: :infinity)
    else
      0
    end
  end

  @doc """
  Query to get the count of multichain_search_db_export_counters_queue entries
  """
  @spec multichain_search_db_export_counters_queue_count() :: integer()
  def multichain_search_db_export_counters_queue_count do
    if multichain_search_enabled?() and not multichain_search_counters_export_queue_disabled?() do
      Repo.aggregate(MultichainSearchDbCountersExportQueue, :count, :timestamp, timeout: :infinity)
    else
      0
    end
  end

  @doc """
  Query to get the count of multichain_search_db_export_token_info_queue entries
  """
  @spec multichain_search_db_export_token_info_queue_count() :: integer()
  def multichain_search_db_export_token_info_queue_count do
    if multichain_search_enabled?() and not multichain_search_token_info_export_queue_disabled?() do
      Repo.aggregate(MultichainSearchDbTokenInfoExportQueue, :count, :address_hash, timeout: :infinity)
    else
      0
    end
  end

  @doc """
  Query to get the count of multichain_search_db_main_export_queue entries
  """
  @spec multichain_search_db_main_export_queue_count() :: integer()
  def multichain_search_db_main_export_queue_count do
    if multichain_search_enabled?() and not multichain_search_main_export_queue_disabled?() do
      Repo.aggregate(MultichainSearchDbMainExportQueue, :count, :hash, timeout: :infinity)
    else
      0
    end
  end

  defp multichain_search_enabled? do
    MultichainSearch.enabled?()
  end

  defp multichain_search_main_export_queue_disabled? do
    :indexer
    |> Application.get_env(Indexer.Fetcher.MultichainSearchDb.MainExportQueue.Supervisor, [])
    |> Keyword.get(:disabled?) == true
  end

  defp multichain_search_balances_export_queue_disabled? do
    :indexer
    |> Application.get_env(Indexer.Fetcher.MultichainSearchDb.BalancesExportQueue.Supervisor, [])
    |> Keyword.get(:disabled?) == true
  end

  defp multichain_search_token_info_export_queue_disabled? do
    :indexer
    |> Application.get_env(Indexer.Fetcher.MultichainSearchDb.TokenInfoExportQueue.Supervisor, [])
    |> Keyword.get(:disabled?) == true
  end

  defp multichain_search_counters_export_queue_disabled? do
    :indexer
    |> Application.get_env(Indexer.Fetcher.MultichainSearchDb.CountersExportQueue.Supervisor, [])
    |> Keyword.get(:disabled?) == true
  end
end
