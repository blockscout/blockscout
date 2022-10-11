defmodule Mix.Tasks.ListEvents do
  @shortdoc "List all events on a given contract"

  @moduledoc """
  Lists all events on a given contract address and their tracked status. Also displays events available on the current (latest block) implementation
    contract should the address represent a proxy contract.

    Usage: mix list_events --contract-address=0x471EcE3750Da237f93B8E339c536989b8978a438

    Output:
  ```
  ##  0x471ece3750da237f93b8e339c536989b8978a438 (GoldTokenProxy) Events

  event name - event topic - already tracked

  Approval - 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925 - untracked
  OwnershipTransferred - 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0 - untracked
  RegistrySet - 0x27fe5f0c1c3b1ed427cc63d0f05759ffdecf9aec9e18d31ef366fc8a6cb5dc3b - untracked
  Transfer - 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef - untracked
  TransferComment - 0xe5d4e30fb8364e57bc4d662a07d0cf36f4c34552004c4c3624620a2c1d1c03dc - untracked
  OwnerSet - 0x50146d0e3c60aa1d17a70635b05494f864e86144a2201275021014fbf08bafe2 - untracked
  ImplementationSet - 0xab64f92ab780ecbf4f3866f57cee465ff36c89450dcce20237ca7a8d81fb7d13 - untracked
  ```
  """

  require Logger
  use Mix.Task
  alias Explorer.Repo
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Mix.Task, as: MixTask

  import Ecto.Query

  def run(args) do
    {options, _args, invalid} = OptionParser.parse(args, strict: [contract_address: :string])

    validate_preconditions(invalid)

    # start ecto repo
    MixTask.run("app.start")

    case SmartContractHelper.get_verified_contract(options[:contract_address]) do
      {:ok, contract} ->
        events = SmartContractHelper.get_all_events(contract)

        already_tracked_events = contract |> get_event_trackings()

        list_events(contract, events, already_tracked_events)

      {:error, reason} ->
        raise "Failure: #{reason}"
    end
  end

  defp validate_preconditions(invalid) do
    unless invalid == [] do
      raise "Invalid options types passed: #{invalid}"
    end

    unless System.get_env("DATABASE_URL") do
      raise "No database connection provided - set DATABASE_URL env variable"
    end
  end

  def get_event_trackings(contract) do
    query = from(cet in Explorer.Chain.Celo.ContractEventTracking, where: cet.smart_contract_id == ^contract.id)
    query |> Repo.all()
  end

  def list_events(contract, events, already_tracked_events) do
    IO.puts("")
    IO.puts("##  #{contract.address_hash |> to_string()} (#{contract.name}) Events")
    IO.puts("")
    IO.puts("  event name - event topic - already tracked")
    IO.puts("")

    tracked_topics = already_tracked_events |> Enum.map(& &1.topic) |> MapSet.new()

    events
    |> Enum.each(fn event ->
      name = event["name"] || "(anonymous)"
      topic = SmartContractHelper.event_abi_to_topic_str(event)
      tracked = MapSet.member?(tracked_topics, topic)

      IO.puts("  #{name} - #{topic} - #{if tracked do
        "tracked"
      else
        "untracked"
      end} ")
    end)
  end
end
