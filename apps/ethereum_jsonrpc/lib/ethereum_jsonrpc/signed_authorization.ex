defmodule EthereumJSONRPC.SignedAuthorization do
  @moduledoc """
  The format of authorization tuples returned for
  set code transactions [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702).
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @typedoc """
  * `"chainId"` - specifies the chain for which the authorization was created `t:EthereumJSONRPC.quantity/0`.
  * `"address"` - `t:EthereumJSONRPC.address/0` of the delegate contract.
  * `"nonce"` - signature nonce `t:EthereumJSONRPC.quantity/0`.
  * `"v"` or `"yParity"` - v component of the signature `t:EthereumJSONRPC.quantity/0`.
  * `"r"` - r component of the signature `t:EthereumJSONRPC.quantity/0`.
  * `"s"` - s component of the signature `t:EthereumJSONRPC.quantity/0`.
  """
  @type t :: %{
          String.t() => EthereumJSONRPC.address() | EthereumJSONRPC.quantity()
        }

  @typedoc """
  * `"chain_id"` - specifies the chain for which the authorization was created.
  * `"address"` - address of the delegate contract.
  * `"nonce"` - signature nonce.
  * `"v"` - v component of the signature.
  * `"r"` - r component of the signature.
  * `"s"` - s component of the signature.
  """
  @type params :: %{
          chain_id: non_neg_integer(),
          address: EthereumJSONRPC.address(),
          nonce: non_neg_integer(),
          r: non_neg_integer(),
          s: non_neg_integer(),
          v: non_neg_integer()
        }

  @doc """
    Converts a signed authorization map into its corresponding parameters map format.

    ## Parameters
    - `raw`: Map with signed authorization data.

    ## Returns
    - Parameters map in the `params()` format.
  """
  @spec to_params(t()) :: params()
  def to_params(raw) do
    %{
      chain_id: quantity_to_integer(raw["chainId"]),
      address: raw["address"],
      nonce: quantity_to_integer(raw["nonce"]),
      r: quantity_to_integer(raw["r"]),
      s: quantity_to_integer(raw["s"]),
      v: quantity_to_integer(raw["v"] || raw["yParity"])
    }
  end
end
