defmodule EthereumJSONRPC.Variant do
  @moduledoc """
  A variant of the Ethereum JSONRPC API.  Each Ethereum client supports slightly different versions of the non-standard
  Ethereum JSONRPC API.  The variant callbacks abstract over this difference.
  """

  alias EthereumJSONRPC.{FetchedBeneficiaries, Transaction}

  @typedoc """
  A module that implements the `EthereumJSONRPC.Variant` behaviour callbacks.
  """
  @type t :: module

  @type internal_transaction_params :: map()
  @type raw_trace_params :: map()

  @doc """
  Fetch the block reward contract beneficiaries for a given blocks from the variant of the Ethereum JSONRPC API.

  For more information on block reward contracts see:
  https://wiki.parity.io/Block-Reward-Contract.html

  ## Returns

   * `{:ok, %EthereumJSONRPC.FetchedBeneficiaries{params_list: [%{address_hash: address_hash, block_number: block_number}], errors: %{code: code, message: message, data: %{block_number: block_number}}}` - some beneficiaries were successfully fetched and some may have had errors.
   * `{:error, reason}` - there was an error at the transport level
   * `:ignore` - the variant does not support fetching beneficiaries
  """
  @callback fetch_beneficiaries([EthereumJSONRPC.block_number()], EthereumJSONRPC.json_rpc_named_arguments()) ::
              {:ok, FetchedBeneficiaries.t()} | {:error, reason :: term} | :ignore

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
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the variant of the Ethereum JSONRPC API.
  Uses API for fetching all internal transactions in the block

  ## Returns

   * `{:ok, [internal_transaction_params]}` - internal transactions were successfully fetched for all blocks
   * `{:error, reason}` - there was one or more errors with `reason` in fetching at least one of the blocks'
       internal transactions
   * `:ignore` - the variant does not support fetching internal transactions.
  """
  @callback fetch_block_internal_transactions(
              [EthereumJSONRPC.block_number()],
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

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the variant of the Ethereum JSONRPC API.
  Uses API for retrieve first trace of transaction

  ## Returns

   * `{:ok, raw_trace_params}` - first trace was successfully retrieved for transaction
   * `{:error, reason}` - there was one or more errors with `reason` in extraction trace of transaction
   * `:ignore` - the variant does not support extraction of trace.
  """
  @callback fetch_first_trace(
              [
                %{
                  hash_data: EthereumJSONRPC.hash(),
                  block_hash: EthereumJSONRPC.hash(),
                  block_number: EthereumJSONRPC.block_number(),
                  transaction_index: Integer
                }
              ],
              EthereumJSONRPC.json_rpc_named_arguments()
            ) :: {:ok, [raw_trace_params]} | {:error, reason :: term} | :ignore

  def get do
    if is_nil(System.get_env("ETHEREUM_JSONRPC_VARIANT")) do
      "nethermind"
    else
      System.get_env("ETHEREUM_JSONRPC_VARIANT")
      |> String.split(".")
      |> List.last()
      |> String.downcase()
    end
  end
end
