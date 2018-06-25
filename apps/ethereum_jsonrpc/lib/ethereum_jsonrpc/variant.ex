defmodule EthereumJSONRPC.Variant do
  @moduledoc """
  A variant of the Ethereum JSONRPC API.  Each Ethereum client supports slightly different versions of the non-standard
  Ethereum JSONRPC API.  The variant callbacks abstract over this difference.
  """

  alias EthereumJSONRPC.Transaction

  @type internal_transaction_params :: map()

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the variant of the Ethereum JSONRPC API.
  """
  @callback fetch_internal_transactions([Transaction.params()]) ::
              {:ok, [internal_transaction_params]} | {:error, reason :: term}
end
