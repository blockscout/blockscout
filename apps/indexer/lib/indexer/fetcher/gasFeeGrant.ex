defmodule Indexer.Fetcher.GasFeeGrant do
  @moduledoc """
  Fetches gas fee grants for validators.

  This module interacts with a precompiled contract to retrieve gas fee grant information
  for a specific validator at a given block height.
  """

  require Logger

  @default_precompile_address "0x0000000000000000000000000000000000000888"
  @default_method_id "12345678"

  @doc """
  Fetches the gas fee grant for a validator at a specific block number.

  ## Parameters

    * `validator_address` - The address of the validator (hex string).
    * `block_number_int` - The block number to query at.

  ## Returns

    * `{:ok, integer()}` - The gas fee grant value.
    * `{:error, any()}` - If the fetch fails.
  """
  @spec fetch(String.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def fetch(validator_address, block_number_int) do
    precompile_address = config(:precompile_address, @default_precompile_address)
    method_id = config(:method_id, @default_method_id)

    # 1. Encode the input (Validator Address padded to 32 bytes)
    clean_address =
      validator_address
      |> String.trim_leading("0x")
      |> String.pad_leading(64, "0")

    data = "0x" <> method_id <> clean_address

    # 2. Convert block number to hex for the RPC call
    block_param = "0x" <> Integer.to_string(block_number_int, 16)

    # 3. Perform eth_call
    case EthereumJSONRPC.execute_contract_call(precompile_address, data, block_param) do
      {:ok, hex_value} ->
        parse_hex_value(hex_value)

      {:error, reason} ->
        Logger.error("Failed to fetch gas fee grant: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_hex_value(hex_value) do
    hex_value
    |> String.trim_leading("0x")
    |> Integer.parse(16)
    |> case do
      {int_val, ""} -> {:ok, int_val}
      _ -> {:error, :invalid_hex_response}
    end
  end

  defp config(key, default) do
    Application.get_env(:indexer, __MODULE__, [])
    |> Keyword.get(key, default)
  end
end
