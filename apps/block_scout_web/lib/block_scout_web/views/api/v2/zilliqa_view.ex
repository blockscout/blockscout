defmodule BlockScoutWeb.API.V2.ZilliqaView do
  @moduledoc """
  View functions for rendering Zilliqa-related data in JSON format.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  if @chain_type == :zilliqa do
    # TODO: remove when https://github.com/elixir-lang/elixir/issues/13975 comes to elixir release
    import Explorer.Chain.Zilliqa.Helper, only: [scilla_transaction?: 1], warn: false
    alias Explorer.Chain.{Address, Block, Transaction}, warn: false
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

    @doc """
    Extends the JSON output with a sub-map containing information related to Zilliqa,
    such as if the transaction is a Scilla transaction.

    ## Parameters
    - `out_json`: A map defining the output JSON which will be extended.
    - `transaction`: The transaction structure.

    ## Returns
    - A map extended with data related to Zilliqa.
    """
    @spec extend_transaction_json_response(map(), Transaction.t()) :: map()
    def extend_transaction_json_response(out_json, %Transaction{} = transaction) do
      Map.put(out_json, :zilliqa, %{
        is_scilla: scilla_transaction?(transaction)
      })
    end

    @doc """
    Extends the JSON output with a sub-map containing information related to
    Zilliqa, such as if the address is a Scilla smart contract.

    ## Parameters
    - `out_json`: A map defining the output JSON which will be extended.
    - `address`: The address structure.

    ## Returns
    - A map extended with data related to Zilliqa.
    """
    @spec extend_address_json_response(map(), Address.t()) :: map()
    def extend_address_json_response(out_json, %Address{} = address) do
      is_scilla_contract =
        case address do
          %Address{
            contract_creation_transaction: transaction
          } ->
            scilla_transaction?(transaction)

          _ ->
            false
        end

      Map.put(out_json, :zilliqa, %{
        is_scilla_contract: is_scilla_contract
      })
    end

    def extend_address_json_response(out_json, _address), do: out_json

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
  else
    def extend_block_json_response(out_json, _, _),
      do: out_json

    def extend_transaction_json_response(out_json, _),
      do: out_json
  end
end
