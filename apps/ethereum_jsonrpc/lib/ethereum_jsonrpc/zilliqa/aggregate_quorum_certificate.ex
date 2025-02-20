defmodule EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate do
  @moduledoc """
  Represents an aggregate quorum certificate associated with the block.
  """
  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Zilliqa.NestedQuorumCertificates

  @type elixir :: %{
          String.t() =>
            EthereumJSONRPC.quantity()
            | EthereumJSONRPC.hash()
            | EthereumJSONRPC.data()
            | NestedQuorumCertificates.elixir()
        }

  @type t :: %__MODULE__{
          block_hash: EthereumJSONRPC.hash(),
          view: non_neg_integer(),
          signature: EthereumJSONRPC.hash(),
          quorum_certificates: NestedQuorumCertificates.t()
        }

  @type params :: %{
          block_hash: EthereumJSONRPC.hash(),
          view: non_neg_integer(),
          signature: EthereumJSONRPC.hash()
        }

  defstruct [:block_hash, :view, :signature, :quorum_certificates]

  @doc """
  Decodes the JSON object returned by JSONRPC node into the `t:t/0` format.

  ## Examples

      iex> aqc_json = %{
      ...>   # "cosigned" => "0x7080000000000000000000000000000000000000000000000000000000000000",
      ...>   "cosigned" => "[0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]",
      ...>   "quorum_certificates" => [
      ...>     %{
      ...>       "block_hash" => "0x4b8939a7fb0d7de4b288bafd4d5caa02f53abf3c1e348fca5038eebbf68248fa",
      ...>       "cosigned" => "0xd080000000000000000000000000000000000000000000000000000000000000",
      ...>       "signature" => "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       "view" => "0x115cc7"
      ...>     },
      ...>     %{
      ...>       "block_hash" => "0x4b8939a7fb0d7de4b288bafd4d5caa02f53abf3c1e348fca5038eebbf68248fa",
      ...>       "cosigned" => "0xd080000000000000000000000000000000000000000000000000000000000000",
      ...>       "signature" => "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       "view" => "0x115cc7"
      ...>     },
      ...>     %{
      ...>       "block_hash" => "0x4b8939a7fb0d7de4b288bafd4d5caa02f53abf3c1e348fca5038eebbf68248fa",
      ...>       "cosigned" => "0xd080000000000000000000000000000000000000000000000000000000000000",
      ...>       "signature" => "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       "view" => "0x115cc7"
      ...>     },
      ...>     %{
      ...>       "block_hash" => "0x4b8939a7fb0d7de4b288bafd4d5caa02f53abf3c1e348fca5038eebbf68248fa",
      ...>       "cosigned" => "0xd080000000000000000000000000000000000000000000000000000000000000",
      ...>       "signature" => "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       "view" => "0x115cc7"
      ...>     }
      ...>   ],
      ...>   "signature" => "0x820f591cd78b29a69ba25bc85c4327fa3b0adb61a73a4f0bd943b4ab0b97e061eae9ac032d19fbfab7efb89fac2454ab0b89fea83185c0dac749ff55b0e2c21535a2b712872491577728db868d11939461a6bfde0d94d238f46b643bbe19767e",
      ...>   "view" => "0x115cca"
      ...> }
      iex> block_hash = "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d"
      iex> EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate.new(aqc_json, block_hash)
      %EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate{
        block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
        view: 1137866,
        signature: "0x820f591cd78b29a69ba25bc85c4327fa3b0adb61a73a4f0bd943b4ab0b97e061eae9ac032d19fbfab7efb89fac2454ab0b89fea83185c0dac749ff55b0e2c21535a2b712872491577728db868d11939461a6bfde0d94d238f46b643bbe19767e",
        quorum_certificates: %EthereumJSONRPC.Zilliqa.NestedQuorumCertificates{
          signers: [1, 2, 3, 8],
          items: [
            %EthereumJSONRPC.Zilliqa.QuorumCertificate{
              block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
              view: 1137863,
              signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
              signers: [0, 1, 3, 8]
            },
            %EthereumJSONRPC.Zilliqa.QuorumCertificate{
              block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
              view: 1137863,
              signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
              signers: [0, 1, 3, 8]
            },
            %EthereumJSONRPC.Zilliqa.QuorumCertificate{
              block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
              view: 1137863,
              signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
              signers: [0, 1, 3, 8]
            },
            %EthereumJSONRPC.Zilliqa.QuorumCertificate{
              block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
              view: 1137863,
              signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
              signers: [0, 1, 3, 8]
            }
          ]
        }
      }
  """
  @spec new(elixir(), EthereumJSONRPC.hash()) :: t()
  def new(
        %{
          "view" => view,
          "signature" => signature,
          "cosigned" => bit_vector,
          "quorum_certificates" => quorum_certificates
        },
        block_hash
      ) do
    %__MODULE__{
      block_hash: block_hash,
      view: quantity_to_integer(view),
      signature: signature,
      quorum_certificates:
        NestedQuorumCertificates.new(
          quorum_certificates,
          bit_vector,
          block_hash
        )
    }
  end

  @doc """
  Converts `t:t/0` format to params used in `Explorer.Chain`.

  ## Examples

      iex> aggregate_quorum_certificate = %EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate{
      ...>   block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>   view: 1137866,
      ...>   signature: "0x820f591cd78b29a69ba25bc85c4327fa3b0adb61a73a4f0bd943b4ab0b97e061eae9ac032d19fbfab7efb89fac2454ab0b89fea83185c0dac749ff55b0e2c21535a2b712872491577728db868d11939461a6bfde0d94d238f46b643bbe19767e",
      ...>   quorum_certificates: %EthereumJSONRPC.Zilliqa.NestedQuorumCertificates{
      ...>     signers: [1, 2, 3, 8],
      ...>     items: [
      ...>       %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>         block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>         view: 1137863,
      ...>         signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>         signers: [0, 1, 3, 8]
      ...>       },
      ...>       %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>         block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>         view: 1137863,
      ...>         signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>         signers: [0, 1, 3, 8]
      ...>       },
      ...>       %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>         block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>         view: 1137863,
      ...>         signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>         signers: [0, 1, 3, 8]
      ...>       },
      ...>       %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>         block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>         view: 1137863,
      ...>         signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>         signers: [0, 1, 3, 8]
      ...>       }
      ...>     ]
      ...>   }
      ...> }
      iex> EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate.to_params(aggregate_quorum_certificate)
      %{
        signature: "0x820f591cd78b29a69ba25bc85c4327fa3b0adb61a73a4f0bd943b4ab0b97e061eae9ac032d19fbfab7efb89fac2454ab0b89fea83185c0dac749ff55b0e2c21535a2b712872491577728db868d11939461a6bfde0d94d238f46b643bbe19767e",
        block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
        view: 1137866
      }
  """
  @spec to_params(t()) :: params()
  def to_params(%__MODULE__{
        block_hash: block_hash,
        view: view,
        signature: signature
      }) do
    %{
      block_hash: block_hash,
      view: view,
      signature: signature
    }
  end
end
