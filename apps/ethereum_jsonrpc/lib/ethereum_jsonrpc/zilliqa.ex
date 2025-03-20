defmodule EthereumJSONRPC.Zilliqa do
  @moduledoc """
  Zilliqa type definitions.
  """
  alias EthereumJSONRPC.Zilliqa.{
    AggregateQuorumCertificate,
    NestedQuorumCertificates,
    QuorumCertificate
  }

  @type consensus_data_params :: %{
          zilliqa_quorum_certificates_params: [QuorumCertificate.params()],
          zilliqa_aggregate_quorum_certificates_params: [AggregateQuorumCertificate.params()],
          zilliqa_nested_quorum_certificates_params: [NestedQuorumCertificates.params()]
        }

  @type validator_index :: non_neg_integer()
  @type signers :: [validator_index()]
end
