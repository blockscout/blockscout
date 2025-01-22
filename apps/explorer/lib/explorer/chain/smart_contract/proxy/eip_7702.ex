defmodule Explorer.Chain.SmartContract.Proxy.EIP7702 do
  @moduledoc """
  Module for fetching EOA delegate from https://eips.ethereum.org/EIPS/eip-7702
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Helper, as: ExplorerHelper

  @doc """
    Retrieves the delegate address hash string for an EIP-7702 compatible EOA.

    This function fetches the contract code for the given address and extracts
    the delegate address according to the EIP-7702 specification.

    ## Parameters
    - `address_hash`: The address of the contract to check.
    - `options`: Optional keyword list of options (default: `[]`).

    ## Returns
    - The delegate address in the hex string format if found and successfully decoded.
    - `nil` if the address doesn't exist, has no contract code, or the delegate address
      couldn't be extracted or decoded.
  """
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: String.t() | nil
  @spec get_implementation_address_hash_string(Hash.Address.t()) :: String.t() | nil
  def get_implementation_address_hash_string(address_hash, options \\ []) do
    case Chain.select_repo(options).get(Address, address_hash) do
      nil ->
        nil

      target_address ->
        contract_code = target_address.contract_code

        case contract_code do
          %Chain.Data{bytes: contract_code_bytes} ->
            contract_code_bytes |> get_delegate_address() |> Proxy.abi_decode_address_output()

          _ ->
            nil
        end
    end
  end

  @doc """
    Extracts the EIP-7702 delegate address from the bytecode.

    This function analyzes the given bytecode to identify and extract the delegate
    address according to the EIP-7702 specification.

    ## Parameters
    - `contract_code_bytes`: The binary representation of the contract bytecode.

    ## Returns
    - A string representation of the delegate address prefixed with "0x" if found.
    - `nil` if the delegate address is not present in the bytecode.

    ## Examples
      iex> get_delegate_address(<<239, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20>>)
      "0x0102030405060708090a0b0c0d0e0f10111213"

      iex> get_delegate_address(<<1, 2, 3>>)
      nil
  """
  @spec get_delegate_address(binary()) :: String.t() | nil
  def get_delegate_address(contract_code_bytes) do
    case contract_code_bytes do
      # 0xef0100 <> address
      <<239, 1, 0>> <> <<address::binary-size(20)>> -> ExplorerHelper.adds_0x_prefix(address)
      _ -> nil
    end
  end
end
