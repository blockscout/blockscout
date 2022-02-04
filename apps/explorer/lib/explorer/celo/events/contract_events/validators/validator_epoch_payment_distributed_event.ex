alias Explorer.Chain.{CeloContractEvent, Log}
alias Explorer.Celo.ContractEvents.EventTransformer

defmodule Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent do
  @moduledoc """
  Struct modelling the Validators.ValidatorEpochPaymentDistributed event

  ValidatorEpochPaymentDistributed(
        address indexed validator,
        uint256 validatorPayment,
        address indexed group,
        uint256 groupPayment
    );
  """

  @name "ValidatorEpochPaymentDistributed"
  @topic "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"

  def name, do: @name
  def topic, do: @topic

  defstruct [
    :transaction_hash,
    :block_hash,
    :contract_address_hash,
    :log_index,
    :validator,
    :validator_payment,
    :group,
    :group_payment,
    name: @name
  ]

  defimpl EventTransformer do
    alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
    alias Explorer.Chain.CeloContractEvent

    import Explorer.Celo.ContractEvents.Common

    def from_log(_, %Log{} = log) do
      params = log |> Map.from_struct()
      from_params(nil, params)
    end

    def from_params(_, params) do
      [validator_payment, group_payment] = decode_data(params.data, [{:uint, 256}, {:uint, 256}])
      validator = decode_event(params.second_topic, :address)
      group = decode_event(params.third_topic, :address)

      %ValidatorEpochPaymentDistributedEvent{
        transaction_hash: params.transaction_hash,
        block_hash: params.block_hash,
        contract_address_hash: params.address_hash,
        log_index: params.index,
        validator: validator,
        validator_payment: validator_payment,
        group: group,
        group_payment: group_payment
      }
    end

    def from_celo_contract_event(_, %CeloContractEvent{params: params} = contract) do
      %{group: group, validator_payment: validator_payment, validator: validator, group_payment: group_payment} =
        params |> normalise_map()

      %ValidatorEpochPaymentDistributedEvent{
        transaction_hash: contract.transaction_hash,
        block_hash: contract.block_hash,
        contract_address_hash: contract.contract_address_hash,
        log_index: contract.log_index,
        validator: validator |> ca(),
        validator_payment: validator_payment,
        group: group |> ca(),
        group_payment: group_payment
      }
    end

    def to_celo_contract_event_params(event) do
      event_params = %{
        params: %{
          group: event.group |> fa(),
          validator_payment: event.validator_payment,
          group_payment: event.group_payment,
          validator: event.validator |> fa()
        }
      }

      event
      |> extract_common_event_params()
      |> Map.merge(event_params)
    end
  end
end
