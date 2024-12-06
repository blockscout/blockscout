defmodule BlockScoutWeb.API.V2.ZilliqaView do
  @moduledoc """
  View functions for rendering Zilliqa-related data in JSON format.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :zilliqa do
    # TODO: remove when https://github.com/elixir-lang/elixir/issues/13975 comes to elixir release
    alias Explorer.Chain.Block, warn: false
    alias Explorer.Chain.Zilliqa.{AggregateQuorumCertificate, QuorumCertificate}, warn: false

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
    @spec extend_block_json_response(map(), Block.t(), boolean()) :: map()
    def extend_block_json_response(out_json, %Block{}, false),
      do: out_json

    def extend_block_json_response(out_json, %Block{zilliqa_view: zilliqa_view} = block, true) do
      zilliqa_json =
        %{view: zilliqa_view}
        |> add_quorum_certificate(block)
        |> add_aggregate_quorum_certificate(block)

      Map.put(out_json, :zilliqa, zilliqa_json)
    end

    @spec add_quorum_certificate(map(), Block.t()) :: map()
    defp add_quorum_certificate(
           zilliqa_json,
           %Block{
             zilliqa_quorum_certificate: %QuorumCertificate{
               view: view,
               signature: signature,
               signers: signers
             }
           }
         ) do
      zilliqa_json
      |> Map.put(:quorum_certificate, %{
        view: view,
        signature: signature,
        signers: signers
      })
    end

    defp add_quorum_certificate(zilliqa_json, _block), do: zilliqa_json

    @spec add_aggregate_quorum_certificate(map(), Block.t()) :: map()
    defp add_aggregate_quorum_certificate(zilliqa_json, %Block{
           zilliqa_aggregate_quorum_certificate: %AggregateQuorumCertificate{
             view: view,
             signature: signature,
             nested_quorum_certificates: nested_quorum_certificates
           }
         })
         when is_list(nested_quorum_certificates) do
      zilliqa_json
      |> Map.put(:aggregate_quorum_certificate, %{
        view: view,
        signature: signature,
        signers:
          Enum.map(
            nested_quorum_certificates,
            & &1.proposed_by_validator_index
          ),
        nested_quorum_certificates:
          Enum.map(
            nested_quorum_certificates,
            &%{
              view: &1.view,
              signature: &1.signature,
              proposed_by_validator_index: &1.proposed_by_validator_index,
              signers: &1.signers
            }
          )
      })
    end

    defp add_aggregate_quorum_certificate(zilliqa_json, _block), do: zilliqa_json
  end
end
