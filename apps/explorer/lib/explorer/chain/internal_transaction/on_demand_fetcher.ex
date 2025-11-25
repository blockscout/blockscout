defmodule Explorer.Chain.InternalTransaction.OnDemandFetcher do
  @moduledoc """
  Behaviour for on-demand fetching of internal transactions from JSON-RPC node.

  This behaviour defines the contract for fetching internal transactions when
  they are not available in the database (e.g., for older blocks where zero-value
  internal transactions have been deleted).

  The implementation lives in the `indexer` app (`Indexer.Fetcher.OnDemand.InternalTransaction`)
  to avoid circular dependencies between `explorer` and `indexer` apps.

  ## Configuration

  Configure the implementation module in your config:

      config :explorer, :on_demand_internal_transaction_fetcher,
        Indexer.Fetcher.OnDemand.InternalTransaction

  In test environment, set to `nil` to disable on-demand fetching:

      config :explorer, :on_demand_internal_transaction_fetcher, nil
  """

  alias Explorer.Chain.{Hash, InternalTransaction, Transaction}

  @doc """
  Fetches internal transactions for the given transaction from node.

  ## Parameters
  - `transaction`: The transaction struct to fetch internal transactions for
  - `options`: Keyword list with optional keys:
    - `:necessity_by_association` - associations to preload as required or optional
    - `:paging_options` - pagination options including page_size and key

  ## Returns
  - List of InternalTransaction structs for the given transaction
  """
  @callback fetch_by_transaction(Transaction.t(), Keyword.t()) :: [InternalTransaction.t()]

  @doc """
  Fetches internal transactions for the given block from node.

  ## Parameters
  - `block_number`: The block number to fetch internal transactions for
  - `options`: Keyword list with optional keys:
    - `:necessity_by_association` - associations to preload as required or optional
    - `:paging_options` - pagination options including page_size and key
    - `:type` - filter by transaction type
    - `:call_type` - filter by call type

  ## Returns
  - List of InternalTransaction structs for the given block
  """
  @callback fetch_by_block(non_neg_integer(), Keyword.t()) :: [InternalTransaction.t()]

  @doc """
  Fetches internal transactions for the given address from node.

  ## Parameters
  - `address_hash`: The address hash to fetch internal transactions for
  - `options`: Keyword list with optional keys:
    - `:necessity_by_association` - associations to preload as required or optional
    - `:paging_options` - pagination options including page_size and key
    - `:direction` - filter by address type (:to, :from, or both)
    - `:from_block` - lower boundary for block number
    - `:to_block` - upper boundary for block number

  ## Returns
  - List of InternalTransaction structs for the given address
  """
  @callback fetch_by_address(Hash.Address.t(), Keyword.t()) :: [InternalTransaction.t()]

  @doc """
  Returns the configured on-demand fetcher module, or nil if not configured.
  """
  @spec fetcher_module() :: module() | nil
  def fetcher_module do
    Application.get_env(:explorer, :on_demand_internal_transaction_fetcher)
  end

  @doc """
  Fetches internal transactions for the given transaction using the configured fetcher.

  Returns an empty list if no fetcher is configured.
  """
  @spec fetch_by_transaction(Transaction.t(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_transaction(transaction, options \\ []) do
    case fetcher_module() do
      nil -> []
      module -> module.fetch_by_transaction(transaction, options)
    end
  end

  @doc """
  Fetches internal transactions for the given block using the configured fetcher.

  Returns an empty list if no fetcher is configured.
  """
  @spec fetch_by_block(non_neg_integer(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_block(block_number, options \\ []) do
    case fetcher_module() do
      nil -> []
      module -> module.fetch_by_block(block_number, options)
    end
  end

  @doc """
  Fetches internal transactions for the given address using the configured fetcher.

  Returns an empty list if no fetcher is configured.
  """
  @spec fetch_by_address(Hash.Address.t(), Keyword.t()) :: [InternalTransaction.t()]
  def fetch_by_address(address_hash, options \\ []) do
    case fetcher_module() do
      nil -> []
      module -> module.fetch_by_address(address_hash, options)
    end
  end
end
