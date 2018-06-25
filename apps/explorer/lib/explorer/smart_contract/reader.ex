defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI).
  """

  alias Explorer.Chain
  alias EthereumJSONRPC.Encoder

  @doc """
  Queries a contract function on the blockchain and returns the call result.

  ## Examples

  Note that for this example to work the database must be up to date with the
  information available in the blockchain.

  Explorer.SmartContract.Reader.query_contract(
    "0x7e50612682b8ee2a8bb94774d50d6c2955726526",
    %{"sum" => [20, 22]}
  )
  # => %{"sum" => [42]}
  """
  @spec query_contract(String.t(), %{String.t() => [term()]}) :: map()
  def query_contract(contract_address, functions) do
    {:ok, address_hash} = Chain.string_to_address_hash(contract_address)

    abi =
      address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    blockchain_result =
      abi
      |> Encoder.encode_abi(functions)
      |> Enum.map(&setup_call_payload(&1, contract_address))
      |> EthereumJSONRPC.execute_contract_functions()

    Encoder.decode_abi_results(blockchain_result, abi, functions)
  end

  @doc """
  Given the encoded data that references a function and its arguments in the blockchain, as well as the contract address, returns what EthereumJSONRPC.execute_contract_functions expects.
  """
  @spec setup_call_payload({%ABI.FunctionSelector{}, [term()]}, String.t()) :: map()
  def setup_call_payload({function_name, data}, contract_address) do
    %{
      contract_address: contract_address,
      data: data,
      id: function_name
    }
  end
end
