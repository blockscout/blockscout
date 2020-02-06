defmodule Explorer.ChainSpec.Parity.Importer do
  @moduledoc """
  Imports data from parity chain spec.
  """

  require Logger

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block.{EmissionReward, Range}
  alias Explorer.Chain.Hash.Address, as: AddressHash
  alias Explorer.Chain.Wei
  alias Explorer.ChainSpec.GenesisData
  alias Explorer.ChainSpec.POA.Importer, as: PoaEmissionImporter

  import Ecto.Query

  @max_block_number :infinity

  def import_emission_rewards(chain_spec) do
    if Application.get_env(:explorer, GenesisData)[:emission_format] == "POA" do
      PoaEmissionImporter.import_emission_rewards()
    else
      import_rewards_from_chain_spec(chain_spec)
    end
  end

  def import_genesis_accounts(chain_spec) do
    balance_params =
      chain_spec
      |> genesis_accounts()
      |> Stream.map(fn balance_map ->
        Map.put(balance_map, :block_number, 0)
      end)
      |> Enum.to_list()

    address_params =
      balance_params
      |> Stream.map(fn %{address_hash: hash} = map ->
        Map.put(map, :hash, hash)
      end)
      |> Enum.to_list()

    params = %{address_coin_balances: %{params: balance_params}, addresses: %{params: address_params}}

    Chain.import(params)
  end

  defp import_rewards_from_chain_spec(chain_spec) do
    rewards = emission_rewards(chain_spec)

    inner_delete_query =
      from(
        emission_reward in EmissionReward,
        # Enforce EmissionReward ShareLocks order (see docs: sharelocks.md)
        order_by: emission_reward.block_range,
        lock: "FOR UPDATE"
      )

    delete_query =
      from(
        e in EmissionReward,
        join: s in subquery(inner_delete_query),
        # we join on reward because it's faster and we have to delete them all anyway
        on: e.reward == s.reward
      )

    # Enforce EmissionReward ShareLocks order (see docs: sharelocks.md)
    ordered_rewards = Enum.sort_by(rewards, & &1.block_range)

    {_, nil} = Repo.delete_all(delete_query)
    {_, nil} = Repo.insert_all(EmissionReward, ordered_rewards)
  end

  def genesis_accounts(chain_spec) do
    accounts = chain_spec["accounts"]

    if accounts do
      parse_accounts(accounts)
    else
      Logger.warn(fn -> "No accounts are defined in chain spec" end)

      []
    end
  end

  def emission_rewards(chain_spec) do
    rewards = chain_spec["engine"]["Ethash"]["params"]["blockReward"]

    if rewards do
      rewards
      |> parse_hex_numbers()
      |> format_ranges()
    else
      Logger.warn(fn -> "No rewards are defined in chain spec" end)

      []
    end
  end

  defp parse_accounts(accounts) do
    accounts
    |> Stream.filter(fn {_address, map} ->
      !is_nil(map["balance"])
    end)
    |> Stream.map(fn {address, %{"balance" => value} = params} ->
      formatted_address = if String.starts_with?(address, "0x"), do: address, else: "0x" <> address
      {:ok, address_hash} = AddressHash.cast(formatted_address)
      balance = parse_number(value)

      nonce = parse_number(params["nonce"] || "0")
      code = params["constructor"]

      %{address_hash: address_hash, value: balance, nonce: nonce, contract_code: code}
    end)
    |> Enum.to_list()
  end

  defp format_ranges(block_number_reward_pairs) do
    block_number_reward_pairs
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn values ->
      create_range(values)
    end)
  end

  defp create_range([{block_number1, reward}, {block_number2, _}]) do
    block_number1 = if block_number1 != 0, do: block_number1 + 1, else: 0

    %{
      block_range: %Range{from: block_number1, to: block_number2},
      reward: reward
    }
  end

  defp create_range([{block_number, reward}]) do
    %{
      block_range: %Range{from: block_number + 1, to: @max_block_number},
      reward: reward
    }
  end

  defp parse_hex_numbers(rewards) when is_map(rewards) do
    Enum.map(rewards, fn {hex_block_number, hex_reward} ->
      block_number = parse_number(hex_block_number)
      {:ok, reward} = hex_reward |> parse_number() |> Wei.cast()

      {block_number, reward}
    end)
  end

  defp parse_hex_numbers(reward) do
    {:ok, reward} = reward |> parse_number() |> Wei.cast()

    [{0, reward}]
  end

  defp parse_number("0x" <> hex_number) do
    {number, ""} = Integer.parse(hex_number, 16)

    number
  end

  defp parse_number(string_number) do
    {number, ""} = Integer.parse(string_number, 10)

    number
  end
end
