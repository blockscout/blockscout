defmodule EthereumJSONRPC.Zilliqa.NestedQuorumCertificates do
  @moduledoc """
  Represents a list of quorum certificates that were proposed by different
  validators in the aggregate quorum certificate.
  """

  import EthereumJSONRPC.Zilliqa.Helper,
    only: [legacy_bit_vector_to_signers: 1]

  # only: [bit_vector_to_signers: 1]

  alias EthereumJSONRPC.Zilliqa
  alias EthereumJSONRPC.Zilliqa.QuorumCertificate

  defstruct [:signers, :items]

  @type elixir :: [QuorumCertificate.elixir()]

  @type t :: %__MODULE__{
          signers: [non_neg_integer()],
          items: [QuorumCertificate.t()]
        }

  @type params :: %{
          proposed_by_validator_index: Zilliqa.validator_index(),
          block_hash: EthereumJSONRPC.hash(),
          view: non_neg_integer(),
          signature: EthereumJSONRPC.hash(),
          signers: Zilliqa.signers()
        }

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
      iex> quorum_certificates = aqc_json["quorum_certificates"]
      iex> bit_vector = aqc_json["cosigned"]
      iex> block_hash = "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d"
      iex> EthereumJSONRPC.Zilliqa.NestedQuorumCertificates.new(quorum_certificates, bit_vector, block_hash)
      %EthereumJSONRPC.Zilliqa.NestedQuorumCertificates{
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
  """
  @spec new([QuorumCertificate.elixir()], EthereumJSONRPC.data(), EthereumJSONRPC.hash()) :: t()
  def new(quorum_certificates, bit_vector, block_hash) do
    signers = legacy_bit_vector_to_signers(bit_vector)
    # TODO: Remove once aggregate quorum certificate also relies on new hex format
    # signers = bit_vector_to_signers(bit_vector)
    items = Enum.map(quorum_certificates, &QuorumCertificate.new(&1, block_hash))

    %__MODULE__{
      signers: signers,
      items: items
    }
  end

  @doc """
  Converts `t:t/0` format to params used in `Explorer.Chain`.

  ## Examples

      iex> nested_quorum_certificates = %EthereumJSONRPC.Zilliqa.NestedQuorumCertificates{
      ...>   signers: [1, 2, 3, 8],
      ...>   items: [
      ...>     %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>       block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>       view: 1137863,
      ...>       signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       signers: [0, 1, 3, 8]
      ...>     },
      ...>     %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>       block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>       view: 1137863,
      ...>       signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       signers: [0, 1, 3, 8]
      ...>     },
      ...>     %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>       block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>       view: 1137863,
      ...>       signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       signers: [0, 1, 3, 8]
      ...>     },
      ...>     %EthereumJSONRPC.Zilliqa.QuorumCertificate{
      ...>       block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
      ...>       view: 1137863,
      ...>       signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
      ...>       signers: [0, 1, 3, 8]
      ...>     }
      ...>   ]
      ...> }
      iex> EthereumJSONRPC.Zilliqa.NestedQuorumCertificates.to_params(nested_quorum_certificates)
      [
        %{
          signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
          block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
          view: 1137863,
          signers: [0, 1, 3, 8],
          proposed_by_validator_index: 1
        },
        %{
          signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
          block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
          view: 1137863,
          signers: [0, 1, 3, 8],
          proposed_by_validator_index: 2
        },
        %{
          signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
          block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
          view: 1137863,
          signers: [0, 1, 3, 8],
          proposed_by_validator_index: 3
        },
        %{
          signature: "0xa78c7f3e07e1df963ddeda17a1e5afd97c7c8a6fc8e0616249c22a2a1cc91f8eef6073cab8ba22b50cc7b38090f1ad9109473d30f24d57858d1f28c6679b3c4deeb800e5572b5e15604596594d506d3103a44d8b707da581f1a4b82310aeecb6",
          block_hash: "0x9c8a047e40ea975cb14c5ccff232a2210fbf5d77b10c748b3559ada0d4adad9d",
          view: 1137863,
          signers: [0, 1, 3, 8],
          proposed_by_validator_index: 8
        }
      ]
  """
  @spec to_params(t()) :: [params()]
  def to_params(%__MODULE__{signers: signers, items: items}) do
    signers
    |> Enum.zip(items)
    |> Enum.map(fn {validator_index, cert} ->
      cert
      |> QuorumCertificate.to_params()
      |> Map.put(:proposed_by_validator_index, validator_index)
    end)
  end
end
