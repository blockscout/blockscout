defmodule Explorer.ChainSpec.Parity.Importer do
  @moduledoc """
  Imports data from parity chain spec.
  """

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block.{EmissionReward, Range}
  alias Explorer.Chain.Hash.Address, as: AddressHash
  alias Explorer.Chain.Wei

  @max_block_number :infinity

  def import_emission_rewards(chain_spec) do
    rewards = emission_rewards(chain_spec)

    {_, nil} = Repo.delete_all(EmissionReward)
    {_, nil} = Repo.insert_all(EmissionReward, rewards)
  end

  def import_genesis_coin_balances(chain_spec) do
    balance_params =
      chain_spec
      |> genesis_coin_balances()
      |> Stream.map(fn balance_map ->
        Map.put(balance_map, :block_number, 0)
      end)
      |> Enum.to_list()

    address_params =
      balance_params
      |> Stream.map(fn %{address_hash: hash} ->
        %{hash: hash}
      end)
      |> Enum.to_list()

    params = %{address_coin_balances: %{params: balance_params}, addresses: %{params: address_params}}

    Chain.import(params)
  end

  def genesis_coin_balances(chain_spec) do
    accounts = chain_spec["accounts"]

    parse_accounts(accounts)
  end

  def emission_rewards(chain_spec) do
    rewards = chain_spec["engine"]["Ethash"]["params"]["blockReward"]

    rewards
    |> parse_hex_numbers()
    |> format_ranges()
  end

  defp parse_accounts(accounts) do
    accounts
    |> Stream.filter(fn {_address, map} ->
      !is_nil(map["balance"])
    end)
    |> Stream.map(fn {address, %{"balance" => value}} ->
      {:ok, address_hash} = AddressHash.cast(address)
      balance = parse_hex_number(value)

      %{address_hash: address_hash, value: balance}
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

  defp parse_hex_numbers(rewards) do
    Enum.map(rewards, fn {hex_block_number, hex_reward} ->
      block_number = parse_hex_number(hex_block_number)
      {:ok, reward} = hex_reward |> parse_hex_number() |> Wei.cast()

      {block_number, reward}
    end)
  end

  defp parse_hex_number("0x" <> hex_number) do
    {number, ""} = Integer.parse(hex_number, 16)

    number
  end
end
