defmodule EthereumJSONRPC.Variant do
  @moduledoc """
  A variant of the Ethereum JSONRPC API.  Each Ethereum client supports slightly different versions of the non-standard
  Ethereum JSONRPC API.  The variant callbacks abstract over this difference.
  """

  alias EthereumJSONRPC.Transaction

  @type internal_transaction_params :: map()

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the variant of the Ethereum JSONRPC API.

  ## Returns

   * `{:ok, [internal_transaction_params]}` - internal transactions were successfully fetched for all transactions
   * `{:error, reason}` - there was one or more errors with `reason` in fetching at least one of the transaction's
       internal transactions
   * `:ignore` - the variant does not support fetching internal transactions.
  """
  @callback fetch_internal_transactions([Transaction.params()]) ::
              {:ok, [internal_transaction_params]} | {:error, reason :: term} | :ignore

  @doc """
  Fetch the `t:Explorer.Chain.Transaction.changeset/2` params for pending transactions from the variant of the Ethereum
  JSONRPC API.

  ## Returns

   * `{:ok, [transaction_params]}` - pending transactions were succucessfully fetched
   * `{:error, reason}` - there was one or more errors with `reason` in fetching the pending transactions
   * `:ignore` - the variant does not support fetching pending transactions.
  """
  @callback fetch_pending_transactions() :: {:ok, [Transaction.params()]} | {:error, reason :: term} | :ignore
end
