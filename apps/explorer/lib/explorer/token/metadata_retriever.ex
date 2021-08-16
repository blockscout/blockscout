defmodule Explorer.Token.MetadataRetriever do
  @moduledoc """
  Reads Token's fields using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Reader

  @contract_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{"name" => "", "type" => "bytes32"}
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint8"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "totalSupply",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint256"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "bytes32"
        }
      ],
      "payable" => false,
      "type" => "function"
    }
  ]

  # 18160ddd = keccak256(totalSupply())
  # 313ce567 = keccak256(decimals())
  # 06fdde03 = keccak256(name())
  # 95d89b41 = keccak256(symbol())
  @contract_functions %{
    "18160ddd" => [],
    "313ce567" => [],
    "06fdde03" => [],
    "95d89b41" => []
  }

  @doc """
  Read functions below in the Smart Contract given the Contract's address hash.

  * totalSupply
  * decimals
  * name
  * symbol

  This function will return a map with functions that were read in the Smart Contract, for instance:

  * Given that all functions were read:
  %{
    name: "BNT",
    decimals: 18,
    total_supply: 1_000_000_000_000_000_000,
    symbol: nil
  }

  * Given that some of them were read:
  %{
    name: "BNT",
    decimals: 18
  }

  It will retry to fetch each function in the Smart Contract according to :token_functions_reader_max_retries
  configured in the application env case one of them raised error.
  """
  @spec get_functions_of([String.t()] | Hash.t() | String.t()) :: Map.t() | {:ok, [Map.t()]}
  def get_functions_of(hashes) when is_list(hashes) do
    requests =
      hashes
      |> Enum.flat_map(fn hash ->
        @contract_functions
        |> Enum.map(fn {method_id, args} ->
          %{contract_address: hash, method_id: method_id, args: args}
        end)
      end)

    updated_at = DateTime.utc_now()

    fetched_result =
      requests
      |> Reader.query_contracts(@contract_abi)
      |> Enum.chunk_every(4)
      |> Enum.zip(hashes)
      |> Enum.map(fn {result, hash} ->
        formatted_result =
          ["name", "totalSupply", "decimals", "symbol"]
          |> Enum.zip(result)
          |> format_contract_functions_result(hash)

        formatted_result
        |> Map.put(:contract_address_hash, hash)
        |> Map.put(:updated_at, updated_at)
      end)

    {:ok, fetched_result}
  end

  def get_functions_of(%Hash{byte_count: unquote(Hash.Address.byte_count())} = address) do
    address_string = Hash.to_string(address)

    get_functions_of(address_string)
  end

  def get_functions_of(contract_address_hash) when is_binary(contract_address_hash) do
    contract_address_hash
    |> fetch_functions_from_contract(@contract_functions)
    |> format_contract_functions_result(contract_address_hash)
  end

  defp fetch_functions_from_contract(contract_address_hash, contract_functions) do
    max_retries = Application.get_env(:explorer, :token_functions_reader_max_retries)

    fetch_functions_with_retries(contract_address_hash, contract_functions, %{}, max_retries)
  end

  defp fetch_functions_with_retries(_contract_address_hash, _contract_functions, accumulator, 0), do: accumulator

  defp fetch_functions_with_retries(contract_address_hash, contract_functions, accumulator, retries_left)
       when retries_left > 0 do
    contract_functions_result = Reader.query_contract(contract_address_hash, @contract_abi, contract_functions)

    functions_with_errors =
      Enum.filter(contract_functions_result, fn function ->
        case function do
          {_, {:error, _}} -> true
          {_, {:ok, _}} -> false
        end
      end)

    if Enum.any?(functions_with_errors) do
      log_functions_with_errors(contract_address_hash, functions_with_errors, retries_left)

      contract_functions_with_errors =
        Map.take(
          contract_functions,
          Enum.map(functions_with_errors, fn {function, _status} -> function end)
        )

      fetch_functions_with_retries(
        contract_address_hash,
        contract_functions_with_errors,
        Map.merge(accumulator, contract_functions_result),
        retries_left - 1
      )
    else
      fetch_functions_with_retries(
        contract_address_hash,
        %{},
        Map.merge(accumulator, contract_functions_result),
        0
      )
    end
  end

  defp log_functions_with_errors(contract_address_hash, functions_with_errors, retries_left) do
    error_messages =
      Enum.map(functions_with_errors, fn {function, {:error, error_message}} ->
        "function: #{function} - error: #{error_message} \n"
      end)

    Logger.debug(
      [
        "<Token contract hash: #{contract_address_hash}> error while fetching metadata: \n",
        error_messages,
        "Retries left: #{retries_left - 1}"
      ],
      fetcher: :token_functions
    )
  end

  defp format_contract_functions_result(contract_functions, contract_address_hash) do
    contract_functions =
      for {method_id, {:ok, [function_data]}} <- contract_functions, into: %{} do
        {atomized_key(method_id), function_data}
      end

    contract_functions
    |> handle_invalid_strings(contract_address_hash)
    |> handle_large_strings
  end

  defp atomized_key("decimals"), do: :decimals
  defp atomized_key("name"), do: :name
  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("totalSupply"), do: :total_supply
  defp atomized_key("313ce567"), do: :decimals
  defp atomized_key("06fdde03"), do: :name
  defp atomized_key("95d89b41"), do: :symbol
  defp atomized_key("18160ddd"), do: :total_supply

  # It's a temp fix to store tokens that have names and/or symbols with characters that the database
  # doesn't accept. See https://github.com/blockscout/blockscout/issues/669 for more info.
  defp handle_invalid_strings(%{name: name, symbol: symbol} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_invalid_strings(%{name: name} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)

    %{contract_functions | name: name}
  end

  defp handle_invalid_strings(%{symbol: symbol} = contract_functions, _contract_address_hash) do
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_invalid_strings(contract_functions, _contract_address_hash), do: contract_functions

  defp handle_invalid_name(nil, _contract_address_hash), do: nil

  defp handle_invalid_name(name, contract_address_hash) do
    case String.valid?(name) do
      true -> remove_null_bytes(name)
      false -> format_according_contract_address_hash(contract_address_hash)
    end
  end

  defp handle_invalid_symbol(symbol) do
    case String.valid?(symbol) do
      true -> remove_null_bytes(symbol)
      false -> nil
    end
  end

  defp format_according_contract_address_hash(contract_address_hash) do
    String.slice(contract_address_hash, 0, 6)
  end

  defp handle_large_strings(%{name: name, symbol: symbol} = contract_functions) do
    [name, symbol] = Enum.map([name, symbol], &handle_large_string/1)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_large_strings(%{name: name} = contract_functions) do
    name = handle_large_string(name)

    %{contract_functions | name: name}
  end

  defp handle_large_strings(%{symbol: symbol} = contract_functions) do
    symbol = handle_large_string(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_large_strings(contract_functions), do: contract_functions

  defp handle_large_string(nil), do: nil
  defp handle_large_string(string), do: handle_large_string(string, byte_size(string))
  defp handle_large_string(string, size) when size > 255, do: binary_part(string, 0, 255)
  defp handle_large_string(string, _size), do: string

  defp remove_null_bytes(string) do
    String.replace(string, "\0", "")
  end
end
