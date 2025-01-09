defmodule EthereumJSONRPC.ERC20 do
  require Logger

  @moduledoc """
    Provides ability to interact with ERC20 token contracts directly.
    Currently supports single method to fetch token properties like
    name, symbol and decimals.
  """

  # decimals()
  @selector_decimals "313ce567"
  # name()
  @selector_name "06fdde03"
  # symbol()
  @selector_symbol "95d89b41"
  @erc20_contract_abi [
    %{
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [
        %{
          "internalType" => "uint8",
          "name" => "",
          "type" => "uint8"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{
          "internalType" => "string",
          "name" => "",
          "type" => "string"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "internalType" => "string",
          "name" => "",
          "type" => "string"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # Retrieve minimal ERC20 token properties (name, symbol, decimals) from the contract
  # needed to display purposes
  #
  # ## Parameters
  # - `token_address`: The address of the token's smart contract.
  # - `properties`: A list of token properties to be requested.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A map with the requested fields containing associated values or nil in case of error
  @spec fetch_token_properties(
          EthereumJSONRPC.address(),
          [:decimals | :name | :symbol],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          %{
            optional(:decimals) => non_neg_integer() | nil,
            optional(:name) => binary() | nil,
            optional(:symbol) => binary() | nil
          }
  def fetch_token_properties(
        token_address,
        properties \\ [:decimals, :name, :symbol],
        json_rpc_named_arguments
      ) do
    method_ids =
      properties
      |> map_properties_to_methods()

    method_ids
    |> Enum.map(fn method_id ->
      %{
        contract_address: token_address,
        method_id: method_id,
        args: []
      }
    end)
    |> EthereumJSONRPC.execute_contract_functions(@erc20_contract_abi, json_rpc_named_arguments)
    |> Enum.zip(method_ids)
    |> Enum.reduce(%{}, fn
      {{:ok, [response]}, method_id}, retval ->
        Map.put(retval, atomized_erc20_selector(method_id), response)

      {{:error, reason}, method_id}, retval ->
        Logger.error(
          "Failed to fetch token #{inspect(token_address)} property (selector #{inspect(method_id)}): #{inspect(reason)}"
        )

        Map.put(retval, atomized_erc20_selector(method_id), nil)
    end)
  end

  # Maps the token properties to the corresponding method selectors in the ERC20 contract
  @spec map_properties_to_methods([:decimals | :name | :symbol]) :: [String.t()]
  defp map_properties_to_methods(properties) do
    Enum.map(properties, fn
      :decimals -> @selector_decimals
      :name -> @selector_name
      :symbol -> @selector_symbol
    end)
  end

  # Converts the selector to the associated token property atom
  @spec atomized_erc20_selector(<<_::64>>) :: atom()
  defp atomized_erc20_selector(@selector_decimals), do: :decimals
  defp atomized_erc20_selector(@selector_name), do: :name
  defp atomized_erc20_selector(@selector_symbol), do: :symbol
end
