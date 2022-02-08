defmodule Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent do
  @moduledoc """
  Struct modelling the Election.ValidatorGroupActiveVoteRevoked event

  ValidatorGroupActiveVoteRevoked(
      address indexed account,
      address indexed group,
      uint256 value,
      uint256 units
    );
  """

  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Chain.{CeloContractEvent, Log}
  import Ecto.Query

  @name "ValidatorGroupActiveVoteRevoked"
  @topic "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8"

  def name, do: @name
  def topic, do: @topic

  defstruct [
    :transaction_hash,
    :block_hash,
    :contract_address_hash,
    :log_index,
    :account,
    :group,
    :value,
    :units,
    name: @name
  ]

  def query do
    from(c in CeloContractEvent, where: c.name == ^@name)
  end

  defimpl EventTransformer do
    alias Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent

    import Explorer.Celo.ContractEvents.Common

    def from_log(_, %Log{} = log) do
      params = log |> Map.from_struct()
      from_params(nil, params)
    end

    def from_params(_, params) do
      [value, units] = decode_data(params.data, [{:uint, 256}, {:uint, 256}])
      account = decode_event(params.second_topic, :address)
      group = decode_event(params.third_topic, :address)

      %ValidatorGroupActiveVoteRevokedEvent{
        transaction_hash: params.transaction_hash,
        block_hash: params.block_hash,
        contract_address_hash: params.address_hash,
        log_index: params.index,
        account: account,
        group: group,
        value: value,
        units: units
      }
    end

    def from_celo_contract_event(_, %CeloContractEvent{params: params} = contract) do
      %{account: account, group: group, value: value, units: units} = params |> normalise_map()

      %ValidatorGroupActiveVoteRevokedEvent{
        transaction_hash: contract.transaction_hash,
        block_hash: contract.block_hash,
        contract_address_hash: contract.contract_address_hash,
        log_index: contract.log_index,
        account: account |> ca(),
        group: group |> ca(),
        value: value,
        units: units
      }
    end

    def to_celo_contract_event_params(event) do
      event_params = %{
        params: %{account: event.account |> fa(), group: event.group |> fa(), value: event.value, units: event.units}
      }

      event
      |> extract_common_event_params()
      |> Map.merge(event_params)
    end
  end
end
