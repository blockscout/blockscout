defmodule EthereumJSONRPC.Zilliqa.QuorumCertificate do
  @moduledoc """
  Represents a quorum certificate associated with the block.
  """
  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import EthereumJSONRPC.Zilliqa.Helper,
    only: [bit_vector_to_signers: 1]

  @type elixir :: %{
          String.t() => EthereumJSONRPC.quantity() | EthereumJSONRPC.data() | EthereumJSONRPC.hash()
        }

  @type t :: %__MODULE__{
          block_hash: EthereumJSONRPC.hash(),
          view: non_neg_integer(),
          signature: EthereumJSONRPC.hash(),
          signers: [non_neg_integer()]
        }

  @type params :: %{
          block_hash: EthereumJSONRPC.hash(),
          view: non_neg_integer(),
          signature: EthereumJSONRPC.hash(),
          signers: [non_neg_integer()]
        }

  defstruct [:block_hash, :view, :signature, :signers]

  @doc """
  Decodes the JSON object returned by JSONRPC node into the `t:t/0` format.

  ## Examples

      iex> qc_json = %{
      ...>   "block_hash" => "0x4b8939a7fb0d7de4b288bafd4d5caa02f53abf3c1e348fca5038eebbf68248fa",
      ...>   "cosigned" => "0xd080000000000000000000000000000000000000000000000000000000000000",
      ...>   "signature" => "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>   "view" => "0x115cc7"
      ...> }
      iex> block_hash = "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d"
      iex> EthereumJSONRPC.Zilliqa.QuorumCertificate.new(qc_json, block_hash)
      %EthereumJSONRPC.Zilliqa.QuorumCertificate{
        block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
        view: 1137863,
        signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
        signers: [0, 1, 3, 8]
      }
  """
  @spec new(elixir(), EthereumJSONRPC.hash()) :: t()
  def new(
        %{
          "view" => view,
          "cosigned" => bit_vector,
          "signature" => signature
        },
        block_hash
      ) do
    %__MODULE__{
      block_hash: block_hash,
      view: quantity_to_integer(view),
      signature: signature,
      signers: bit_vector_to_signers(bit_vector)
    }
  end

  @doc """
  Converts `t:t/0` format to params used in `Explorer.Chain`.

  ## Examples

      iex> qc = %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>   block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>   view: 1137863,
      ...>   signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>   signers: [0, 1, 3, 8]
      ...> }
      iex> EthereumJSONRPC.Zilliqa.QuorumCertificate.to_params(qc)
      %{
        block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
        view: 1137863,
        signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
        signers: [0, 1, 3, 8]
      }
  """
  @spec to_params(t()) :: params()
  def to_params(%__MODULE__{
        block_hash: block_hash,
        view: view,
        signature: signature,
        signers: signers
      }) do
    %{
      block_hash: block_hash,
      view: view,
      signature: signature,
      signers: signers
    }
  end
end
