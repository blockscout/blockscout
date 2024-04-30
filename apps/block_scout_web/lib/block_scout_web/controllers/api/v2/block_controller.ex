defmodule BlockScoutWeb.API.V2.BlockController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      next_page_params: 4,
      paging_options: 1,
      put_key_value_to_paging_options: 3,
      split_list_by_page: 1,
      parse_block_hash_or_number_param: 1
    ]

  import BlockScoutWeb.PagingHelper,
    only: [delete_parameters_from_next_page_params: 1, select_block_type: 1, type_filter_options: 1]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias BlockScoutWeb.API.V2.{TransactionView, WithdrawalView}
  alias Explorer.Chain
  alias Explorer.Chain.InternalTransaction

  case Application.compile_env(:explorer, :chain_type) do
    :ethereum ->
      @chain_type_transaction_necessity_by_association %{
        :beacon_blob_transaction => :optional
      }
      @chain_type_block_necessity_by_association %{
        [transactions: :beacon_blob_transaction] => :optional
      }

    :zksync ->
      @chain_type_transaction_necessity_by_association %{}
      @chain_type_block_necessity_by_association %{
        :zksync_batch => :optional,
        :zksync_commit_transaction => :optional,
        :zksync_prove_transaction => :optional,
        :zksync_execute_transaction => :optional
      }

    _ ->
      @chain_type_transaction_necessity_by_association %{}
      @chain_type_block_necessity_by_association %{}
  end

  @transaction_necessity_by_association [
    necessity_by_association:
      %{
        [created_contract_address: :names] => :optional,
        [from_address: :names] => :optional,
        [to_address: :names] => :optional,
        :block => :optional,
        [created_contract_address: :smart_contract] => :optional,
        [from_address: :smart_contract] => :optional,
        [to_address: :smart_contract] => :optional
      }
      |> Map.merge(@chain_type_transaction_necessity_by_association)
  ]

  @internal_transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  @api_true [api?: true]

  @block_params [
    necessity_by_association:
      %{
        [miner: :names] => :optional,
        :uncles => :optional,
        :nephews => :optional,
        :rewards => :optional,
        :transactions => :optional,
        :withdrawals => :optional
      }
      |> Map.merge(@chain_type_block_necessity_by_association),
    api?: true
  ]

  @block_params [
    necessity_by_association:
      %{
        [miner: :names] => :optional,
        :uncles => :optional,
        :nephews => :optional,
        :rewards => :optional,
        :transactions => :optional,
        :withdrawals => :optional
      }
      |> Map.merge(@chain_type_block_necessity_by_association),
    api?: true
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number` endpoint.
  """
  @spec block(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def block(conn, %{"block_hash_or_number" => block_hash_or_number}) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number, @block_params) do
      conn
      |> put_status(200)
      |> render(:block, %{block: block})
    end
  end

  defp fetch_block(:hash, hash, params) do
    Chain.hash_to_block(hash, params)
  end

  defp fetch_block(:number, number, params) do
    case Chain.number_to_block(number, params) do
      {:ok, _block} = ok_response ->
        ok_response

      _ ->
        {:lost_consensus, Chain.nonconsensus_block_by_number(number, @api_true)}
    end
  end

  @doc """
  Function to handle GET requests to `/api/v2/blocks` endpoint.
  """
  @spec blocks(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def blocks(conn, params) do
    full_options = select_block_type(params)

    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> Chain.list_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    next_page_params = next_page |> next_page_params(blocks, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:blocks, %{
      blocks: blocks |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number/transactions` endpoint.
  """
  @spec transactions(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def transactions(conn, %{"block_hash_or_number" => block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        @transaction_necessity_by_association
        |> Keyword.merge(put_key_value_to_paging_options(paging_options(params), :is_index_in_asc_order, true))
        |> Keyword.merge(type_filter_options(params))
        |> Keyword.merge(@api_true)

      transactions_plus_one = Chain.block_to_transactions(block.hash, full_options, false)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:transactions, %{
        transactions: transactions |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number/internal-transactions` endpoint.
  """
  @spec internal_transactions(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def internal_transactions(conn, %{"block_hash_or_number" => block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        @internal_transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(@api_true)

      internal_transactions_plus_one = InternalTransaction.block_to_internal_transactions(block.hash, full_options)

      {internal_transactions, next_page} = split_list_by_page(internal_transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(
          internal_transactions,
          delete_parameters_from_next_page_params(params),
          &InternalTransaction.internal_transaction_to_block_paging_options/1
        )

      conn
      |> put_status(200)
      |> put_view(TransactionView)
      |> render(:internal_transactions, %{
        internal_transactions: internal_transactions,
        next_page_params: next_page_params,
        block: block
      })
    end
  end

  @doc """
  Function to handle GET requests to `/api/v2/blocks/:block_hash_or_number/withdrawals` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) ::
          {:error, :not_found | {:invalid, :hash | :number}}
          | {:lost_consensus, {:error, :not_found} | {:ok, Explorer.Chain.Block.t()}}
          | Plug.Conn.t()
  def withdrawals(conn, %{"block_hash_or_number" => block_hash_or_number} = params) do
    with {:ok, block} <- block_param_to_block(block_hash_or_number) do
      full_options =
        [necessity_by_association: %{address: :optional}, api?: true]
        |> Keyword.merge(paging_options(params))

      withdrawals_plus_one = Chain.block_to_withdrawals(block.hash, full_options)
      {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

      next_page_params = next_page |> next_page_params(withdrawals, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> put_view(WithdrawalView)
      |> render(:withdrawals, %{
        withdrawals: withdrawals |> maybe_preload_ens() |> maybe_preload_metadata(),
        next_page_params: next_page_params
      })
    end
  end

  defp block_param_to_block(block_hash_or_number, options \\ @api_true) do
    with {:ok, type, value} <- parse_block_hash_or_number_param(block_hash_or_number) do
      fetch_block(type, value, options)
    end
  end
end
