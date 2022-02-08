# This file is auto generated, changes will be lost upon regeneration

defmodule Explorer.Celo.ContractEvents.EventMap do
  @moduledoc "Map event names and event topics to concrete contract event structs"

  alias Explorer.Celo.ContractEvents.EventTransformer

  @doc "Convert ethrpc log parameters to CeloContractEvent insertion parameters"
  def rpc_to_event_params(logs) when is_list(logs) do
    logs
    |> Enum.map(fn params = %{first_topic: event_topic} ->
      case event_for_topic(event_topic) do
        nil ->
          nil

        event ->
          event
          |> struct!()
          |> EventTransformer.from_params(params)
          |> EventTransformer.to_celo_contract_event_params()
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc "Convert CeloContractEvent instance to their concrete types"
  def celo_contract_event_to_concrete_event(events) when is_list(events) do
    events
    |> Enum.map(&celo_contract_event_to_concrete_event/1)
    |> Enum.reject(&is_nil/1)
  end

  def celo_contract_event_to_concrete_event(%{name: name} = params) do
    case event_for_name(name) do
      nil ->
        nil

      event ->
        event
        |> struct!()
        |> EventTransformer.from_celo_contract_event(params)
    end
  end

  @doc "Convert concrete event to CeloContractEvent insertion parameters"
  def event_to_contract_event_params(events) when is_list(events) do
    events |> Enum.map(&event_to_contract_event_params/1)
  end

  def event_to_contract_event_params(event) do
    event |> EventTransformer.to_celo_contract_event_params()
  end

  @topic_to_event %{
    "0x45aac85f38083b18efe2d441a65b9c1ae177c78307cb5a5d4aec8f7dbcaeabfe" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent,
    "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7" =>
      Elixir.Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent,
    "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent,
    "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  }

  @name_to_event %{
    "ValidatorGroupVoteActivated" => Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent,
    "EpochRewardsDistributedToVoters" =>
      Elixir.Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent,
    "ValidatorGroupActiveVoteRevoked" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent,
    "ValidatorEpochPaymentDistributed" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  }

  def event_for_topic(topic), do: Map.get(@topic_to_event, topic)
  def event_for_name(name), do: Map.get(@name_to_event, name)
end
