defmodule Mix.Tasks.TrackEvent do
  @shortdoc "Track events of verified contracts"
  @moduledoc """
      Configures the indexer to start tracking specific events of a given verified smart contract.

      Events can be specified by topic, by name, or a flag `all` to track all events on the contract.

      Validation errors will be displayed in the console should the event not exist or be tracked already.

      ## Examples

      * Track an event with the name "Swap" on a contract
          * `mix track_event --contract-address=0xF35ED7156BABF2541E032B3BB8625210316E2832 --event-names=Swap`
      * Track multiple events via name
          * `mix track_event --contract-address=0xF35ED7156BABF2541E032B3BB8625210316E2832 --event-names=Swap,Transfer,TransferWithComment`
      * Track multiple events via topic
          * `mix track_event --contract-address=0xF35ED7156BABF2541E032B3BB8625210316E2832 --topics=0x6dc84b66cc948d847632b9d829f7cb1cb904fbf2c084554a9bc22ad9d8453340,0xc68a9b88effd8a11611ff410efbc83569f0031b7bc70dd455b61344c7f0a042f`
      * Track all events on contract
          * `mix track_event --contract-address=0xF35ED7156BABF2541E032B3BB8625210316E2832 --all`
  """
  use Mix.Task
  require Logger

  alias Explorer.Chain.Celo.ContractEventTracking
  alias Explorer.Repo
  alias Explorer.SmartContract.Helper, as: SmartContractHelper
  alias Mix.Task, as: MixTask

  def run(args) do
    {options, _args, invalid} =
      OptionParser.parse(args, strict: [contract_address: :string, topics: :string, event_names: :string, all: :boolean])

    validate_preconditions(invalid)

    # start ecto repo
    MixTask.run("app.start")

    with {:ok, contract} <- SmartContractHelper.get_verified_contract(options[:contract_address]),
         {:ok, tracking_changesets} <-
           create_changesets(contract, options[:topics], options[:event_names], options[:all]) do
      tracking_changesets
      |> Enum.each(fn changeset ->
        case Repo.insert(changeset) do
          {:ok, cet = %ContractEventTracking{}} ->
            Logger.info(
              "Tracking new instances of #{cet.topic} (#{cet.name}) on contract #{contract.address_hash |> to_string()} (#{contract.name})"
            )

          {:error, %Ecto.Changeset{errors: errors, changes: %{name: name, topic: topic}}} ->
            Logger.error("Errors found with event #{topic} (#{name})")
            Logger.error(inspect(errors))
        end
      end)
    else
      {:error, reason} ->
        raise "Failure: #{reason}"
    end
  end

  defp create_changesets(contract, _topics, _names, true) do
    changesets =
      contract
      |> SmartContractHelper.get_all_events()
      |> Enum.map(fn event_abi = %{"name" => name} ->
        case ContractEventTracking.from_event_abi(contract, event_abi) do
          cet = %Ecto.Changeset{valid?: true} ->
            cet

          %Ecto.Changeset{valid?: false, errors: errors} ->
            raise "Errors found with event name #{name} - #{errors}"
        end
      end)

    {:ok, changesets}
  end

  defp create_changesets(contract, _topics, names, _all) when is_binary(names) do
    names = names |> String.split(",")

    trackings =
      names
      |> Enum.map(fn name ->
        case ContractEventTracking.from_event_name(contract, name) do
          cet = %Ecto.Changeset{valid?: true} ->
            cet

          %Ecto.Changeset{valid?: false, errors: errors} ->
            raise "Errors found with event name #{name} - #{errors}"

          nil ->
            raise "Event name #{name} not found in contract #{contract.name}"
        end
      end)

    {:ok, trackings}
  end

  defp create_changesets(contract, topics, _names, _all) when is_list(topics) do
    trackings =
      topics
      |> Enum.map(fn topic ->
        case ContractEventTracking.from_event_topic(contract, topic) do
          cet = %Ecto.Changeset{valid?: true} ->
            cet

          %Ecto.Changeset{valid?: false, errors: errors} ->
            raise "Errors found with event name #{topic} - #{errors}"

          nil ->
            raise "Event topic #{topic} not found in contract #{contract.name}"
        end
      end)

    {:ok, trackings}
  end

  defp create_changesets(contract, topics, _names, _all) when is_binary(topics) do
    topics = topics |> String.split(",")
    create_changesets(contract, topics, nil, nil)
  end

  defp validate_preconditions(invalid) do
    unless invalid == [] do
      raise "Invalid options types passed: #{invalid}"
    end

    unless System.get_env("DATABASE_URL") do
      raise "No database connection provided - set DATABASE_URL env variable"
    end
  end
end
