defmodule Explorer.ChainSpec.Geth.Importer do
  @moduledoc """
  Imports data from Geth genesis.json.
  """

  require Logger

  alias EthereumJSONRPC.Blocks
  alias Explorer.{Chain, Helper}
  alias Explorer.Chain.Hash.Address

  @doc """
    Imports genesis accounts into the database from a chain specification.

    This function extracts genesis account information from a given chain specification,
    including initial balances and contract bytecode. It enriches this data with additional
    metadata, such as setting the block number to 0 (for genesis accounts) and determining
    the day based on the timestamp of the first block. Subsequently, it imports the data
    into `Explorer.Chain.Address`, `Explorer.Chain.Address.CoinBalance`, and
    `Explorer.Chain.Address.CoinBalanceDaily` tables.

    ## Parameters
    - `chain_spec`: A map or list representing the chain specification that contains
                    genesis account information. It may be structured directly as an
                    account list or as part of a larger specification map.

    ## Returns
    - N/A
  """
  @spec import_genesis_accounts(map() | list()) :: any()
  def import_genesis_accounts(chain_spec) do
    # credo:disable-for-previous-line Credo.Check.Design.DuplicatedCode
    # It duplicates `import_genesis_accounts/1` from `Explorer.ChainSpec.Parity.Importer`
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

  @doc """
    Parses and returns the genesis account information from a chain specification.

    It extracts account data such as address hashes, initial balances, and
    optionally, contract bytecode for accounts defined in the genesis block of
    a blockchain configuration.

    ## Parameters
    - `input`: Can be a list of account maps or a map of the entire chain specification.

    ## Returns
    - A list of maps, each representing an account with keys for the address hash,
      balance , and optionally, the contract bytecode. Accounts without defined
      balances are omitted.

    ### Usage
    - `genesis_accounts(%{"genesis" => genesis_data})`: Extracts accounts from
      a nested genesis key.
    - `genesis_accounts(chain_spec)`: Parses accounts from a chain specification that
      includes an 'alloc' key.
    - `genesis_accounts(list_of_accounts)`: Directly parses a list of account data.
      Intended to be called after `genesis_accounts(%{"genesis" => genesis_data})` call.
  """
  @spec genesis_accounts(map() | list()) :: [
          %{address_hash: Address.t(), value: non_neg_integer(), contract_code: String.t()}
        ]
  def genesis_accounts(%{"genesis" => genesis}) do
    genesis_accounts(genesis)
  end

  def genesis_accounts(raw_accounts) when is_list(raw_accounts) do
    raw_accounts
    |> Enum.map(fn account ->
      with {:ok, address_hash} <- Chain.string_to_address_hash(account["address"]),
           balance <- Helper.parse_number(account["balance"]) do
        %{address_hash: address_hash, value: balance, contract_code: account["bytecode"]}
      else
        _ -> nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  def genesis_accounts(chain_spec) when is_map(chain_spec) do
    accounts = chain_spec["alloc"]

    if accounts do
      parse_accounts(accounts)
    else
      Logger.warning(fn -> "No accounts are defined in genesis" end)

      []
    end
  end

  # Parses account data from a provided map to extract address, balance, and optional contract code.
  #
  # ## Parameters
  # - `accounts`: A map with accounts data.
  #
  # ## Returns
  # - A list of maps with accounts data including address hashes, balances,
  #   and any associated contract code.
  @spec parse_accounts(%{binary() => map()}) :: [
          %{:address_hash => Address.t(), value: non_neg_integer(), contract_code: String.t() | nil}
        ]
  defp parse_accounts(accounts) do
    accounts
    |> Stream.filter(fn {_address, map} ->
      !is_nil(map["balance"])
    end)
    |> Stream.map(fn {address, %{"balance" => value} = params} ->
      formatted_address = if String.starts_with?(address, "0x"), do: address, else: "0x" <> address
      {:ok, address_hash} = Address.cast(formatted_address)
      balance = Helper.parse_number(value)

      code = params["code"]

      %{address_hash: address_hash, value: balance, contract_code: code}
    end)
    |> Enum.to_list()
  end
end
