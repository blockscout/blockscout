defmodule EthereumJSONRPC.Variant do
  @moduledoc """
  A variant of the Ethereum JSONRPC API.  Each Ethereum client supports slightly different versions of the non-standard
  Ethereum JSONRPC API.  The variant callbacks abstract over this difference.
  """

  alias EthereumJSONRPC.Transaction

  @typedoc """
  A module that implements the `EthereumJSONRPC.Variant` behaviour callbacks.
  """
  @type t :: module

  @type internal_transaction_params :: map()

  @doc """
  Fetch the block reward contract beneficiaries for a given block
  range, from the variant of the Ethereum JSONRPC API.

  For more information on block reward contracts see:
  https://wiki.parity.io/Block-Reward-Contract.html

  ## Returns

   * `{:ok, #MapSet<[%{...}]>}` - beneficiaries were successfully fetched
   * `{:error, reason}` - there was one or more errors with `reason` in fetching the beneficiaries
   * `:ignore` - the variant does not support fetching beneficiaries
  """
  @callback fetch_beneficiaries(Range.t(), EthereumJSONRPC.json_rpc_named_arguments()) ::
              {:ok, MapSet.t()} | {:error, reason :: term} | :ignore

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the variant of the Ethereum JSONRPC API.

  ## Returns

   * `{:ok, [internal_transaction_params]}` - internal transactions were successfully fetched for all transactions
   * `{:error, reason}` - there was one or more errors with `reason` in fetching at least one of the transaction's
       internal transactions
   * `:ignore` - the variant does not support fetching internal transactions.
  """
  @callback fetch_internal_transactions(
              [%{hash_data: EthereumJSONRPC.hash()}],
              EthereumJSONRPC.json_rpc_named_arguments()
            ) :: {:ok, [internal_transaction_params]} | {:error, reason :: term} | :ignore

  @doc """
  Fetch the `t:Explorer.Chain.Transaction.changeset/2` params for pending transactions from the variant of the Ethereum
  JSONRPC API.

  ## Returns

   * `{:ok, [transaction_params]}` - pending transactions were successfully fetched
   * `{:error, reason}` - there was one or more errors with `reason` in fetching the pending transactions
   * `:ignore` - the variant does not support fetching pending transactions.
  """
  @callback fetch_pending_transactions(EthereumJSONRPC.json_rpc_named_arguments()) ::
              {:ok, [Transaction.params()]} | {:error, reason :: term} | :ignore
end
