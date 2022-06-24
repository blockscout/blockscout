defmodule Explorer.ENS.NameRetriever do
  @moduledoc """
  Retrieves ENS Domain Name from registry using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.SmartContract.Reader

  @regex ~r/^((.*)\.)?([^.]+)$/
  def namehash(name) do
    namehash(
      String.downcase(name),
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    )
  end

  defp namehash(name, hash) do
    case byte_size(name) do
      0 ->
        hash

      _ ->
        partition = Regex.run(@regex, name)

        case partition do
          nil ->
            {:error, "Invalid ENS name"}

          matches ->
            [rest, label] = [Enum.at(matches, 2), Enum.at(matches, 3)]
            new_hash = ExKeccak.hash_256(hash <> ExKeccak.hash_256(label))

            case byte_size(rest) do
              0 -> new_hash
              _ -> namehash(rest, new_hash)
            end
        end
    end
  end

  @registry_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "bytes32",
          "name" => "node",
          "type" => "bytes32"
        }
      ],
      "name" => "resolver",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]
  # 0178b8bf = keccak256(resolver(bytes32))
  @resolver_function "0178b8bf"

  @resolver_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "bytes32",
          "name" => "node",
          "type" => "bytes32"
        }
      ],
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
      "constant" => true,
      "inputs" => [
        %{
          "name" => "node",
          "type" => "bytes32"
        }
      ],
      "name" => "addr",
      "outputs" => [
        %{
          "name" => "ret",
          "type" => "address"
        }
      ],
      "payable" => false,
      "type" => "function"
    }
  ]
  # 691f3431 = keccak256(name(bytes32))
  @name_function "691f3431"
  # 3b3b57de = keccak256(addr(bytes32))
  @addr_function "3b3b57de"

  def fetch_address_of(name) do
    case enabled?() do
      false ->
        {:error, "ENS support was not enabled"}

      true ->
        case namehash(name) do
          {:error, message} ->
            {:error, message}

          namehash ->
            resolver_result =
              case resolver_address() do
                nil ->
                  registry_address()
                  |> query_contract(%{@resolver_function => [namehash]}, @registry_abi)
                  |> handle_resolver_result(name)

                address ->
                  {:ok, address}
              end

            case resolver_result do
              {:error, error} ->
                {:error, error}

              {:ok, resolver_address} ->
                resolver_functions = %{@addr_function => [namehash]}

                resolver_address
                |> query_contract(resolver_functions, @resolver_abi)
                |> handle_address_result(name)
            end
        end
    end
  end

  def fetch_name_of(address) do
    case enabled?() do
      false ->
        {:error, "ENS support was not enabled"}

      true ->
        reverse_address = String.downcase(String.slice(address, 2..-1)) <> ".addr.reverse"
        reverse_address_hash = namehash(reverse_address)

        resolver_result =
          case resolver_address() do
            nil ->
              registry_address()
              |> query_contract(%{@resolver_function => [reverse_address_hash]}, @registry_abi)
              |> handle_resolver_result(reverse_address)

            address ->
              {:ok, address}
          end

        case resolver_result do
          {:error, error} ->
            {:error, error}

          {:ok, resolver_address} ->
            resolver_functions = %{@name_function => [reverse_address_hash]}

            resolver_address
            |> query_contract(resolver_functions, @resolver_abi)
            |> handle_name_result()
        end
    end
  end

  def handle_resolver_result(%{@resolver_function => {:ok, [address_str]}}, name) do
    case address_str do
      "0x0000000000000000000000000000000000000000" -> {:error, "Failed to look up ENS resolver address for #{name}"}
      _ -> {:ok, address_str}
    end
  end

  def handle_resolver_result(%{@resolver_function => {:error, error}}, _) do
    {:error, error}
  end

  def handle_address_result(%{@addr_function => {:ok, [address_str]}}, name) do
    case address_str do
      "0x0000000000000000000000000000000000000000" -> {:error, "Failed to look up ENS address for #{name}"}
      _ -> {:ok, address_str}
    end
  end

  def handle_address_result(%{@addr_function => {:error, error}}, _) do
    {:error, error}
  end

  def handle_name_result(%{@name_function => {:ok, [name]}}) do
    case byte_size(name) do
      0 ->
        {:error, "ENS name not found"}

      _ ->
        case name do
          "0x0000000000000000000000000000000000000000" ->
            {:error, "Primary ENS name was unset"}

          _ ->
            {:ok, handle_large_string(name)}
        end
    end
  end

  def handle_name_result(%{@name_function => {:error, error}}) do
    {:error, error}
  end

  def query_contract(contract_address, contract_functions, abi) do
    Reader.query_contract(contract_address, abi, contract_functions, true)
  end

  defp handle_large_string(string), do: handle_large_string(string, byte_size(string))
  defp handle_large_string(string, size) when size > 255, do: shorten_to_valid_utf(binary_part(string, 0, 255))
  defp handle_large_string(string, _size), do: string

  def shorten_to_valid_utf(string) do
    case String.valid?(string) do
      true -> string
      false -> shorten_to_valid_utf(binary_part(string, 0, byte_size(string) - 1))
    end
  end

  defp config(key) do
    :explorer
    |> Application.get_env(__MODULE__)
    |> Keyword.get(key)
  end

  defp enabled? do
    config(:enabled)
  end

  defp registry_address do
    config(:registry_address)
  end

  defp resolver_address do
    config(:resolver_address)
  end
end
