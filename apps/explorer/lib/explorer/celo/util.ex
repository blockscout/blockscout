defmodule Explorer.Celo.Util do
  @moduledoc """
  Utilities for reading from Celo smart contracts
  """

  require Logger
  alias Explorer.Celo.{AbiHandler, AddressCache}
  alias Explorer.SmartContract.Reader

  @celo_token_contract_symbols %{
    "stableToken" => "cUSD",
    "stableTokenEUR" => "cEUR",
    "stableTokenREAL" => "cREAL",
    # cGLD is the old symbol, needs to be updated to CELO
    "goldToken" => "cGLD"
  }

  def call_methods(methods) do
    contract_abi = AbiHandler.get_abi()

    methods
    |> Enum.map(&format_request/1)
    |> Enum.filter(fn req -> req.contract_address != :error end)
    |> Enum.map(fn %{contract_address: {:ok, address}} = req -> Map.put(req, :contract_address, address) end)
    |> Reader.query_contracts_by_name(contract_abi)
    |> Enum.zip(methods)
    |> Enum.into(%{}, fn
      {response, {_, function_name, _}} -> {function_name, response}
      {response, {_, function_name, _, _}} -> {function_name, response}
    end)
  end

  defp format_request({contract_name, function_name, params}) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
      args: params
    }
  end

  defp format_request({contract_name, function_name, params, bn}) do
    %{
      contract_address: contract(contract_name),
      function_name: function_name,
      args: params,
      block_number: bn
    }
  end

  defp contract(:blockchainparameters), do: get_address("BlockchainParameters")
  defp contract(:lockedgold), do: get_address("LockedGold")
  defp contract(:validators), do: get_address("Validators")
  defp contract(:election), do: get_address("Election")
  defp contract(:epochrewards), do: get_address("EpochRewards")
  defp contract(:accounts), do: get_address("Accounts")
  defp contract(:gold), do: get_address("GoldToken")
  defp contract(:usd), do: get_address("StableToken")
  defp contract(:eur), do: get_address("StableTokenEUR")
  defp contract(:real), do: get_address("StableTokenREAL")

  def get_address(name) do
    case AddressCache.contract_address(name) do
      :error -> {:error}
      address -> {:ok, address}
    end
  end

  def get_token_contract_names do
    Map.keys(@celo_token_contract_symbols)
  end

  def get_token_contract_symbols do
    Map.values(@celo_token_contract_symbols)
  end

  def contract_name_to_symbol(name, use_celo_instead_cgld?) do
    case name do
      n when n in [nil, "goldToken"] ->
        if(use_celo_instead_cgld?, do: "CELO", else: "cGLD")

      _ ->
        @celo_token_contract_symbols[name]
    end
  end
end
