defmodule BlockScoutWeb.API.V2.ZilliqaView do
  @moduledoc """
  View functions for rendering Zilliqa-related data in JSON format.
  """

  alias Explorer.Chain.Block

  @doc """
  Extends the JSON output with a sub-map containing information related to Zilliqa,
  such as the quorum certificate and aggregate quorum certificate.

  ## Parameters
  - `out_json`: A map defining the output JSON which will be extended.
  - `block`: The block structure containing Zilliqa-related data.
  - `single_block?`: A boolean indicating if it is a single block.

  ## Returns
  - A map extended with data related to Zilliqa.
  """
  @spec extend_block_json_response(map(), Explorer.Chain.Block.t(), boolean()) :: map()
  def extend_block_json_response(out_json, %Block{}, false),
    do: out_json

  def extend_block_json_response(out_json, %Block{} = block, true) do
    zilliqa_json =
      %{}
      |> add_quorum_certificate(block)
      |> add_aggregate_quorum_certificate(block)

    Map.put(out_json, :zilliqa, zilliqa_json)
  end

  @spec add_quorum_certificate(map(), Block.t()) :: map()
  defp add_quorum_certificate(
         zilliqa_json,
         %Block{} = block
       ) do
    qc_json =
      block
      |> Map.get(:zilliqa_quorum_certificate)
      |> case do
        nil ->
          nil

        qc ->
          zilliqa_json
          |> Map.put(:quorum_certificate, %{
            view: qc.view,
            signature: qc.signature,
            signers: qc.signers
          })
      end

    zilliqa_json
    |> Map.put(:quorum_certificate, qc_json)
  end

  @spec add_aggregate_quorum_certificate(map(), Block.t()) :: map()
  defp add_aggregate_quorum_certificate(zilliqa_json, %Block{} = block) do
    aqc_json =
      block
      |> Map.get(:zilliqa_aggregate_quorum_certificate)
      |> case do
        nil ->
          nil

        aqc ->
          signers =
            aqc.nested_quorum_certificates
            |> Enum.map(& &1.proposed_by_validator_index)

          %{
            view: aqc.view,
            signature: aqc.signature,
            signers: signers,
            nested_quorum_certificates:
              Enum.map(
                aqc.nested_quorum_certificates,
                &%{
                  view: &1.view,
                  signature: &1.signature,
                  signers: &1.signers,
                  proposed_by_validator_index: &1.proposed_by_validator_index
                }
              )
          }
      end

    zilliqa_json
    |> Map.put(:aggregate_quorum_certificate, aqc_json)
  end
end
