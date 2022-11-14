# credo:disable-for-this-file
defmodule Explorer.ChainSpec.Geth.Importer do
  @moduledoc """
  Imports data from Geth genesis.json.
  """

  require Logger

  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain
  alias Explorer.Chain.Hash.Address, as: AddressHash

  def import_genesis_accounts(chain_spec) do
    balance_params =
      chain_spec
      |> genesis_accounts()
      |> Stream.map(fn balance_map ->
        Map.put(balance_map, :block_number, 0)
      end)
      |> Enum.to_list()

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    {:ok, %Blocks{blocks_params: [%{timestamp: timestamp}]}} =
      EthereumJSONRPC.fetch_blocks_by_range(1..1, json_rpc_named_arguments)

    day = DateTime.to_date(timestamp)

    balance_daily_params =
      chain_spec
      |> genesis_accounts()
      |> Stream.map(fn balance_map ->
        Map.put(balance_map, :day, day)
      end)
      |> Enum.to_list()

    address_params =
      balance_params
      |> Stream.map(fn %{address_hash: hash} = map ->
        Map.put(map, :hash, hash)
      end)
      |> Enum.to_list()

    params = %{
      address_coin_balances: %{params: balance_params},
      address_coin_balances_daily: %{params: balance_daily_params},
      addresses: %{params: address_params}
    }

    Chain.import(params)
  end

  def genesis_accounts(chain_spec) do
    accounts = chain_spec["alloc"]

    if accounts do
      parse_accounts(accounts)
    else
      Logger.warn(fn -> "No accounts are defined in genesis" end)

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

      code = params["code"]

      %{address_hash: address_hash, value: balance, contract_code: code}
    end)
    |> Enum.to_list()
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
