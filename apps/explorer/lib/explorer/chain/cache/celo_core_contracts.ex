defmodule Explorer.Chain.Cache.CeloCoreContracts do
  @moduledoc """
  Cache for Celo core contract addresses.
  """
  @dialyzer :no_match

  require Logger

  @atom_to_contract_name %{
    accounts: "Accounts",
    celo_token: "GoldToken",
    election: "Election",
    epoch_rewards: "EpochRewards",
    locked_gold: "LockedGold",
    reserve: "Reserve",
    usd_token: "StableToken",
    validators: "Validators",
    governance: "Governance",
    fee_handler: "FeeHandler"
  }

  @atom_to_contract_event_names %{
    fee_handler: %{
      fee_beneficiary_set: "FeeBeneficiarySet",
      burn_fraction_set: "BurnFractionSet"
    },
    epoch_rewards: %{
      carbon_offsetting_fund_set: "CarbonOffsettingFundSet"
    }
  }

  def atom_to_contract_name, do: @atom_to_contract_name
  def atom_to_contract_event_names, do: @atom_to_contract_event_names

  def get_event(contract_atom, event_atom, block_number) do
    core_contracts = Application.get_env(:explorer, __MODULE__)[:contracts]

    with {:ok, address} when not is_nil(address) <- get_address(contract_atom, block_number),
         {:contract_atom, {:ok, contract_name}} <-
           {:contract_atom, Map.fetch(@atom_to_contract_name, contract_atom)},
         {:event_atom, {:ok, event_name}} <-
           {
             :event_atom,
             @atom_to_contract_event_names
             |> Map.get(contract_atom, %{})
             |> Map.fetch(event_atom)
           },
         {:events, {:ok, contract_name_to_addresses}} <-
           {:events, Map.fetch(core_contracts, "events")},
         {:contract_name, {:ok, contract_addresses}} <-
           {:contract_name, Map.fetch(contract_name_to_addresses, contract_name)},
         {:contract_address, {:ok, contract_events}} <-
           {:contract_address, Map.fetch(contract_addresses, address)},
         {:event_name, {:ok, event_updates}} <-
           {:event_name, Map.fetch(contract_events, event_name)} do
      current_event =
        event_updates
        |> Enum.take_while(&(&1["updated_at_block_number"] <= block_number))
        |> Enum.take(-1)
        |> List.first()

      {:ok, current_event}
    else
      nil ->
        {:ok, nil}

      {:contract_atom, :error} ->
        Logger.error("Unknown contract atom: #{inspect(contract_atom)}")
        {:error, :contract_atom_not_found}

      {:event_atom, :error} ->
        Logger.error("Unknown event atom: #{inspect(event_atom)}")
        {:error, :event_atom_not_found}

      {:events, :error} ->
        raise "Missing `events` key in CELO core contracts JSON"

      {:contract_name, :error} ->
        Logger.error(fn ->
          [
            "Unknown name for contract atom: #{contract_atom}, ",
            "ensure `CELO_CORE_CONTRACTS` env var is set ",
            "and the provided JSON contains required key"
          ]
        end)

        {:error, :contract_name_not_found}

      {:event_name, :error} ->
        Logger.error(fn ->
          [
            "Unknown name for event atom: #{event_atom}, ",
            "ensure `CELO_CORE_CONTRACTS` env var is set ",
            "and the provided JSON contains required key"
          ]
        end)

        {:error, :event_name_not_found}

      {:contract_address, :error} ->
        Logger.error(fn ->
          [
            "Unknown address for contract atom: #{contract_atom}, ",
            "ensure `CELO_CORE_CONTRACTS` env var is set ",
            "and the provided JSON contains required key"
          ]
        end)

        {:error, :contract_address_not_found}

      error ->
        error
    end
  end

  def get_address(
        contract_atom,
        block_number
      ) do
    core_contracts = Application.get_env(:explorer, __MODULE__)[:contracts]

    with {:atom, {:ok, contract_name}} <-
           {:atom, Map.fetch(@atom_to_contract_name, contract_atom)},
         {:addresses, {:ok, contract_name_to_addresses}} <-
           {:addresses, Map.fetch(core_contracts, "addresses")},
         {:name, {:ok, address_updates}} <-
           {:name, Map.fetch(contract_name_to_addresses, contract_name)} do
      current_address =
        address_updates
        |> Enum.take_while(&(&1["updated_at_block_number"] <= block_number))
        |> Enum.take(-1)
        |> case do
          [%{"address" => address}] ->
            address

          _ ->
            nil
        end

      {:ok, current_address}
    else
      {:atom, :error} ->
        Logger.error("Unknown contract atom: #{inspect(contract_atom)}")
        {:error, :contract_atom_not_found}

      {:addresses, :error} ->
        raise "Missing `addresses` key in CELO core contracts JSON"

      {:name, :error} ->
        Logger.error(fn ->
          [
            "Unknown name for contract atom: #{contract_atom}, ",
            "ensure `CELO_CORE_CONTRACTS` env var is set ",
            "and the provided JSON contains required key"
          ]
        end)

        {:error, :contract_name_not_found}
    end
  end
end
