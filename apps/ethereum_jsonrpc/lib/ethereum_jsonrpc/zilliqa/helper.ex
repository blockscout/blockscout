defmodule EthereumJSONRPC.Zilliqa.Helper do
  @moduledoc """
  Helper functions for processing consensus data.
  """
  alias EthereumJSONRPC.Zilliqa
  alias EthereumJSONRPC.{Block, Blocks}

  alias EthereumJSONRPC.Zilliqa.{
    AggregateQuorumCertificate,
    NestedQuorumCertificates,
    QuorumCertificate
  }

  @initial_acc %{
    zilliqa_quorum_certificates_params: [],
    zilliqa_aggregate_quorum_certificates_params: [],
    zilliqa_nested_quorum_certificates_params: []
  }

  @type consensus_data_params :: %{
          zilliqa_quorum_certificates_params: [QuorumCertificate.params()],
          zilliqa_aggregate_quorum_certificates_params: [AggregateQuorumCertificate.params()],
          zilliqa_nested_quorum_certificates_params: [NestedQuorumCertificates.params()]
        }

  @spec extend_blocks_struct(Blocks.t(), Blocks.elixir()) :: Blocks.t()
  def extend_blocks_struct(%Blocks{} = module, elixir_blocks) do
    consensus_data_fields =
      Enum.reduce(
        elixir_blocks,
        @initial_acc,
        &reduce_to_consensus_data/2
      )

    Map.merge(module, consensus_data_fields)
  end

  @doc """
  Converts a list of bits to a list of indexes where the bit is equal 1.

  ## Examples

      iex> EthereumJSONRPC.Zilliqa.Helper.legacy_bit_vector_to_signers("[1, 0, 1, 0]")
      [0, 2]

      iex> EthereumJSONRPC.Zilliqa.Helper.legacy_bit_vector_to_signers("[1, 1, 1, 1]")
      [0, 1, 2, 3]

  TODO: Remove once aggregate quorum certificate also relies on new hex format
  """
  @spec legacy_bit_vector_to_signers(binary()) :: Zilliqa.signers()
  def legacy_bit_vector_to_signers(bit_list_json_string) do
    bit_list_json_string
    |> Jason.decode!()
    |> Enum.with_index()
    |> Enum.filter(fn {bit, _} -> bit == 1 end)
    |> Enum.map(fn {_, index} -> index end)
  end

  @doc """
  Converts a number in hex to a list of indexes where the bit in the binary
  representation of this number is equal 1.

  ## Examples

      iex> EthereumJSONRPC.Zilliqa.Helper.bit_vector_to_signers("0xa000000000000000000000000000000000000000000000000000000000000000")
      [0, 2]

      iex> EthereumJSONRPC.Zilliqa.Helper.bit_vector_to_signers("0xf000000000000000000000000000000000000000000000000000000000000000")
      [0, 1, 2, 3]
  """
  @spec bit_vector_to_signers(EthereumJSONRPC.data()) :: Zilliqa.signers()
  def bit_vector_to_signers(hex) when is_binary(hex) do
    hex
    |> String.trim_leading("0x")
    |> String.graphemes()
    |> Enum.flat_map(&hex_char_to_bits/1)
    |> Enum.with_index()
    |> Enum.filter(fn {bit, _} -> bit == 1 end)
    |> Enum.map(fn {_, index} -> index end)
  end

  @spec hex_char_to_bits(binary()) :: [integer()]
  defp hex_char_to_bits(char) do
    char
    |> String.to_integer(16)
    |> Integer.to_string(2)
    |> String.pad_leading(4, "0")
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
  end

  @spec reduce_to_consensus_data(
          Block.elixir(),
          consensus_data_params()
        ) :: consensus_data_params()
  defp reduce_to_consensus_data(
         elixir_block,
         %{
           zilliqa_quorum_certificates_params: quorum_certificates_params_acc,
           zilliqa_aggregate_quorum_certificates_params: aggregate_quorum_certificates_params_acc,
           zilliqa_nested_quorum_certificates_params: aggregate_nested_quorum_certificates_params_acc
         }
       ) do
    quorum_certificates_map =
      elixir_block
      |> Block.elixir_to_zilliqa_quorum_certificate()
      |> case do
        nil ->
          %{zilliqa_quorum_certificates_params: quorum_certificates_params_acc}

        quorum_certificate ->
          quorum_certificate_params = QuorumCertificate.to_params(quorum_certificate)
          %{zilliqa_quorum_certificates_params: [quorum_certificate_params | quorum_certificates_params_acc]}
      end

    aggregated_quorum_certificate_map =
      elixir_block
      |> Block.elixir_to_zilliqa_aggregate_quorum_certificate()
      |> case do
        nil ->
          %{
            zilliqa_aggregate_quorum_certificates_params: aggregate_quorum_certificates_params_acc,
            zilliqa_nested_quorum_certificates_params: aggregate_nested_quorum_certificates_params_acc
          }

        aggregate_quorum_certificates ->
          aggregate_quorum_certificate_params =
            AggregateQuorumCertificate.to_params(aggregate_quorum_certificates)

          aggregate_nested_quorum_certificates_params =
            NestedQuorumCertificates.to_params(aggregate_quorum_certificates.quorum_certificates)

          %{
            zilliqa_aggregate_quorum_certificates_params: [
              aggregate_quorum_certificate_params | aggregate_quorum_certificates_params_acc
            ],
            zilliqa_nested_quorum_certificates_params:
              aggregate_nested_quorum_certificates_params ++ aggregate_nested_quorum_certificates_params_acc
          }
      end

    Map.merge(quorum_certificates_map, aggregated_quorum_certificate_map)
  end
end
