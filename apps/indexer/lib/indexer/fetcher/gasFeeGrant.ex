defmodule Indexer.Fetcher.GasFeeGrant do
  @moduledoc """
  Fetches gas fee grants for validators.

  This module interacts with a precompiled contract to retrieve gas fee grant information
  for a specific validator at a given block height.
  """

  require Logger

  @default_precompile_address "0x0000000000000000000000000000000000001006"

  # periodCanSpend(address,address)
  @grant_method_id "f2403dcd"

  @doc """
  Fetches the gas fee grant details for a grantee and program.

  ## Parameters
    * `grantee` - The address of the grantee (hex string).
    * `program` - The address of the program (hex string).
    * `block_number_int` - The block number to query at (optional, defaults to latest).

  ## Returns
    * `{:ok, %{granter: String.t(), period_can_spend: integer()}}`
    * `{:error, any()}`
  """
  def fetch_grant(grantee, program, block_number_int \\ nil) do
    precompile_address = config(:precompile_address, @default_precompile_address)
    method_id = config(:grant_method_id, @grant_method_id)

    # 1. Encode the input
    clean_grantee = clean_address(grantee)
    clean_program = clean_address(program)

    data = "0x" <> method_id <> clean_grantee <> clean_program

    # 2. Convert block number to hex for the RPC call
    block_param =
      if block_number_int, do: "0x" <> Integer.to_string(block_number_int, 16), else: "latest"

    # 3. Perform eth_call
    case EthereumJSONRPC.execute_contract_call(precompile_address, data, block_param) do
      {:ok, hex_value} ->
        parse_grant_response(hex_value)

      {:error, reason} ->
        Logger.error("Failed to fetch gas fee grant: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp clean_address(address) do
    address
    |> String.trim_leading("0x")
    |> String.pad_leading(64, "0")
  end

  defp parse_grant_response(hex_value) do
    # Remove 0x
    hex = String.trim_leading(hex_value, "0x")

    # Check if we have enough data (at least 5 words to get to periodCanSpend)
    # 9 words total = 9 * 64 chars = 576 chars
    if String.length(hex) >= 576 do
      # Word 0: Granter (Address)
      granter_hex = String.slice(hex, 0, 64)
      granter = "0x" <> String.slice(granter_hex, 24, 40)

      # Word 4: PeriodCanSpend
      period_can_spend_hex = String.slice(hex, 256, 64)

      case Integer.parse(period_can_spend_hex, 16) do
        {period_can_spend, ""} ->
          {:ok, %{granter: granter, period_can_spend: period_can_spend}}

        _ ->
          {:error, :invalid_hex_value}
      end
    else
      {:error, :invalid_response_length}
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
