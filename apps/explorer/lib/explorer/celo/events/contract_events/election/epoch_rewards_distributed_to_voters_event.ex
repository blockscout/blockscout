alias Explorer.Chain.{CeloContractEvent, Log}
alias Explorer.Celo.ContractEvents.EventTransformer

defmodule Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent do
  @moduledoc """
  Struct modelling the Election.EpochRewardsDistributedToVoters event

  EpochRewardsDistributedToVoters(
      address indexed group,
      uint256 value
    );
  """

  @name "EpochRewardsDistributedToVoters"
  @topic "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7"

  def name, do: @name
  def topic, do: @topic

  defstruct [
    :transaction_hash,
    :block_hash,
    :contract_address_hash,
    :log_index,
    :group,
    :value,
    name: @name
  ]

  defimpl EventTransformer do
    alias Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent

    import Explorer.Celo.ContractEvents.Common

    def from_log(_, %Log{} = log) do
      params = log |> Map.from_struct()
      from_params(nil, params)
    end

    def from_params(_, params) do
      [value] = decode_data(params.data, [{:uint, 256}])
      group = decode_event(params.second_topic, :address)

      %EpochRewardsDistributedToVotersEvent{
        transaction_hash: params.transaction_hash,
        block_hash: params.block_hash,
        contract_address_hash: params.address_hash,
        log_index: params.index,
        group: group,
        value: value
      }
    end

    def from_celo_contract_event(_, %CeloContractEvent{params: params} = contract) do
      %{group: group, value: value} = params |> normalise_map()

      %EpochRewardsDistributedToVotersEvent{
        transaction_hash: contract.transaction_hash,
        block_hash: contract.block_hash,
        contract_address_hash: contract.contract_address_hash,
        log_index: contract.log_index,
        group: group |> ca(),
        value: value
      }
    end

    def to_celo_contract_event_params(event) do
      event_params = %{params: %{group: event.group |> fa(), value: event.value}}

      event
      |> extract_common_event_params()
      |> Map.merge(event_params)
    end
  end
end
