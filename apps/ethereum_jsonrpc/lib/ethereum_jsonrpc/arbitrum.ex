defmodule EthereumJSONRPC.Arbitrum do
  @moduledoc """
  Arbitrum specific routines used to fetch and process
  data from the associated JSONRPC endpoint
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  require Logger
  alias ABI.TypeDecoder

  @type event_data :: %{
          :data => binary(),
          :first_topic => binary(),
          :second_topic => binary(),
          :third_topic => binary(),
          :fourth_topic => binary()
        }

  @l2_to_l1_event_unindexed_params [
    :address,
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    :bytes
  ]

  @doc """
    Parses an L2-to-L1 event, extracting relevant information from the event's data.

    This function takes an L2ToL1Tx event emitted by ArbSys contract and parses its fields
    to extract needed message properties.

    ## Parameters
    - `event`: A log entry representing an L2-to-L1 message event.

    ## Returns
    - A tuple of fields of L2-to-L1 message with the following order:
        [position,
        caller,
        destination,
        arb_block_number,
        eth_block_number,
        timestamp,
        callvalue,
        data]
  """
  @spec l2_to_l1_event_parse(event_data) :: {
          non_neg_integer(),
          # Hash.Address.t(),
          binary(),
          # Hash.Address.t(),
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          binary()
        }
  def l2_to_l1_event_parse(event) do
    # Logger.warning("event.data: #{inspect(Data.to_string(event.data))}")

    [
      caller,
      arb_block_number,
      eth_block_number,
      timestamp,
      callvalue,
      data
    ] =
      event.data
      |> decode_data(@l2_to_l1_event_unindexed_params)

    position =
      case quantity_to_integer(event.fourth_topic) do
        nil -> 0
        number -> number
      end

    # {:ok, caller_addr} = Hash.Address.cast(caller)

    # {:ok, destination} = hex_value_to_integer(event.second_topic)

    caller_string = value_to_address(caller)
    destination_string = value_to_address(event.second_topic)

    {position, caller_string, destination_string, arb_block_number, eth_block_number, timestamp, callvalue, data}
  end

  @spec decode_data(binary() | map(), list()) :: list() | nil
  defp decode_data("0x", types) do
    for _ <- types, do: nil
  end

  defp decode_data("0x" <> encoded_data, types) do
    decode_data(encoded_data, types)
  end

  defp decode_data(encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  @spec value_to_address(non_neg_integer() | binary()) :: String.t()
  defp value_to_address(value) do
    hex =
      cond do
        is_integer(value) -> Integer.to_string(value, 16)
        is_binary(value) and String.starts_with?(value, "0x") -> String.trim_leading(value, "0x")
        is_binary(value) -> Base.encode16(value, case: :lower)
        true -> raise ArgumentError, "Unsupported address format"
      end

    padded_hex =
      hex
      |> String.trim_leading("0")
      |> String.pad_leading(40, "0")

    "0x" <> padded_hex
  end
end
