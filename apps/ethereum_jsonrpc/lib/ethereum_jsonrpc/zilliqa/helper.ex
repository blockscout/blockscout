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

  @spec extend_blocks_struct(Blocks.t(), [Block.elixir()]) :: Blocks.t()
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
  Converts a bit vector string to a list of indexes where the bit corresponding
  to signing validator is 1.

  ## Examples

      iex> bit_vector_to_signers("[1, 0, 1, 0]")
      [0, 2]

      iex> bit_vector_to_signers("[1, 1, 1, 1]")
      [0, 1, 2, 3]
  """
  @spec bit_vector_to_signers(Zilliqa.bit_vector()) :: Zilliqa.signers()
  def bit_vector_to_signers(bit_vector_string) do
    bit_vector_string
    |> Jason.decode!()
    |> Enum.with_index()
    |> Enum.filter(fn {bit, _} -> bit == 1 end)
    |> Enum.map(fn {_, index} -> index end)
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
    quorum_certificates =
      Block.elixir_to_zilliqa_quorum_certificate(elixir_block)

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

    quorum_certificates_params = QuorumCertificate.to_params(quorum_certificates)

    %{
      zilliqa_quorum_certificates_params: [
        quorum_certificates_params | quorum_certificates_params_acc
      ]
    }
    |> Map.merge(aggregated_quorum_certificate_map)
  end
end
