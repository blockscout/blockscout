# This file is auto generated, changes will be lost upon regeneration

defmodule Explorer.Celo.ContractEvents.EventMap do
  @moduledoc "Map event names and event topics to concrete contract event structs"

  alias Explorer.Celo.ContractEvents.EventTransformer
  alias Explorer.Repo

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

  def celo_contract_event_to_concrete_event(%{topic: topic} = params) do
    case event_for_topic(topic) do
      nil ->
        nil

      event ->
        event
        |> struct!()
        |> EventTransformer.from_celo_contract_event(params)
    end
  end

  @doc "Run ecto query and convert all CeloContractEvents into their concrete types"
  def query_all(query) do
    query
    |> Repo.all()
    |> celo_contract_event_to_concrete_event()
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
    "0x60c5b4756af49d7b071b00dbf0f87af605cce11896ecd3b760d19f0f9d3fbcef" =>
      Elixir.Explorer.Celo.ContractEvents.Governance.ConstitutionSetEvent,
    "0x55b488abd19ae7621712324d3d42c2ef7a9575f64f5503103286a1161fb40855" =>
      Elixir.Explorer.Celo.ContractEvents.Reserve.AssetAllocationSetEvent,
    "0x91ba34d62474c14d6c623cd322f4256666c7a45b7fdaa3378e009d39dfcec2a7" =>
      Elixir.Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent,
    "0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc" =>
      Elixir.Explorer.Celo.ContractEvents.Goldtoken.TransferCommentEvent,
    "0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc" =>
      Elixir.Explorer.Celo.ContractEvents.Stabletoken.TransferCommentEvent,
    "0xae7458f8697a680da6be36406ea0b8f40164915ac9cc40c0dad05a2ff6e8c6a8" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent,
    "0xd3532f70444893db82221041edb4dc26c94593aeb364b0b14dfc77d5ee905152" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteCastEvent,
    "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent,
    "0x213377eec2c15b21fa7abcbb0cb87a67e893cdb94a2564aa4bb4d380869473c8" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEcdsaPublicKeyUpdatedEvent
  }

  @name_to_event %{
    "ValidatorGroupVoteActivated" => Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent,
    "ConstitutionSet" => Elixir.Explorer.Celo.ContractEvents.Governance.ConstitutionSetEvent,
    "AssetAllocationSet" => Elixir.Explorer.Celo.ContractEvents.Reserve.AssetAllocationSetEvent,
    "EpochRewardsDistributedToVoters" =>
      Elixir.Explorer.Celo.ContractEvents.Election.EpochRewardsDistributedToVotersEvent,
    "TransferComment" => Elixir.Explorer.Celo.ContractEvents.Goldtoken.TransferCommentEvent,
    "TransferComment" => Elixir.Explorer.Celo.ContractEvents.Stabletoken.TransferCommentEvent,
    "ValidatorGroupActiveVoteRevoked" =>
      Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupActiveVoteRevokedEvent,
    "ValidatorGroupVoteCast" => Elixir.Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteCastEvent,
    "ValidatorEpochPaymentDistributed" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent,
    "ValidatorEcdsaPublicKeyUpdated" =>
      Elixir.Explorer.Celo.ContractEvents.Validators.ValidatorEcdsaPublicKeyUpdatedEvent
  }

  def event_for_topic(topic), do: Map.get(@topic_to_event, topic)
  def maps, do: {@name_to_event, @topic_to_event}
end
