defmodule EthereumJSONRPC.Arbitrum do
  @moduledoc """
  Arbitrum specific routines used to fetch and process
  data from the associated JSONRPC endpoint
  """

  import EthereumJSONRPC

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

  # outbox()
  @selector_outbox "ce11e6ab"
  # sequencerInbox()
  @selector_sequencer_inbox "ee35f327"
  # bridge()
  @selector_bridge "e78cea92"
  @rollup_contract_abi [
    %{
      "inputs" => [],
      "name" => "outbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "sequencerInbox",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "bridge",
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

  # constructOutboxProof(uint64 size, uint64 leaf)
  @selector_construct_outbox_proof "42696350"
  @node_interface_contract_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "uint64",
          "name" => "size",
          "type" => "uint64"
        },
        %{
          "internalType" => "uint64",
          "name" => "leaf",
          "type" => "uint64"
        }
      ],
      "name" => "constructOutboxProof",
      "outputs" => [
        %{
          "internalType" => "bytes32",
          "name" => "send",
          "type" => "bytes32"
        },
        %{
          "internalType" => "bytes32",
          "name" => "root",
          "type" => "bytes32"
        },
        %{
          "internalType" => "bytes32[]",
          "name" => "proof",
          "type" => "bytes32[]"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  # isSpent(uint256 index)
  @selector_is_spent "5a129efe"
  @outbox_contract_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "uint256",
          "name" => "index",
          "type" => "uint256"
        }
      ],
      "name" => "isSpent",
      "outputs" => [
        %{
          "internalType" => "bool",
          "name" => "",
          "type" => "bool"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
    Retrieves specific contract addresses associated with Arbitrum rollup contract.

    This function fetches the addresses of the bridge, sequencer inbox, and outbox
    contracts related to the specified Arbitrum rollup address. It invokes one of
    the contract methods `bridge()`, `sequencerInbox()`, or `outbox()` based on
    the `contracts_set` parameter to obtain the required information.

    ## Parameters
    - `rollup_address`: The address of the Arbitrum rollup contract from which
                        information is being retrieved.
    - `contracts_set`: A symbol indicating the set of contracts to retrieve (`:bridge`
                       for the bridge contract, `:inbox_outbox` for the sequencer
                       inbox and outbox contracts).
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.

    ## Returns
    - A map with keys corresponding to the contract types (`:bridge`, `:sequencer_inbox`,
      `:outbox`) and values representing the contract addresses.
  """
  @spec get_contracts_for_rollup(
          EthereumJSONRPC.address(),
          :bridge | :inbox_outbox,
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: %{(:bridge | :sequencer_inbox | :outbox) => binary()}
  def get_contracts_for_rollup(rollup_address, contracts_set, json_rpc_named_arguments)

  def get_contracts_for_rollup(rollup_address, :bridge, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(rollup_address, [@selector_bridge], json_rpc_named_arguments)
  end

  def get_contracts_for_rollup(rollup_address, :inbox_outbox, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(
      rollup_address,
      [@selector_sequencer_inbox, @selector_outbox],
      json_rpc_named_arguments
    )
  end

  # Calls getter functions on a rollup contract and collects their return values.
  #
  # This function is designed to interact with a rollup contract and invoke specified getter methods.
  # It creates a list of requests for each method ID, executes these requests with retries as needed,
  # and then maps the results to the corresponding method IDs.
  #
  # ## Parameters
  # - `rollup_address`: The address of the rollup contract to interact with.
  # - `method_ids`: A list of method identifiers representing the getter functions to be called.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A map where each key is a method identifier converted to an atom, and each value is the
  #   response from calling the respective method on the contract.
  defp call_simple_getters_in_rollup_contract(rollup_address, method_ids, json_rpc_named_arguments) do
    method_ids
    |> Enum.map(fn method_id ->
      %{
        contract_address: rollup_address,
        method_id: method_id,
        args: []
      }
    end)
    |> EthereumJSONRPC.execute_contract_functions(@rollup_contract_abi, json_rpc_named_arguments)
    |> Enum.zip(method_ids)
    |> Enum.reduce(%{}, fn {{:ok, [response]}, method_id}, retval ->
      Map.put(retval, atomized_key(method_id), response)
    end)
  end

  defp atomized_key(@selector_outbox), do: :outbox
  defp atomized_key(@selector_sequencer_inbox), do: :sequencer_inbox
  defp atomized_key(@selector_bridge), do: :bridge

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

    caller_string = value_to_address(caller)
    destination_string = value_to_address(event.second_topic)

    {position, caller_string, destination_string, arb_block_number, eth_block_number, timestamp, callvalue, data}
  end

  # Decode ABI-encoded data in accordance with the provided types
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

  # Casting value into the Ethereum address (hex-string, 0x-prefixed)
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

  # Calculates the proof needed to claim L2->L1 message
  #
  # This function calls the `constructOutboxProof` method of the Node Interface
  # to obtain the data needed for manual message claiming
  #
  # Parameters:
  # - `node_interface_address`: The address of the node interface contract.
  # - `size`: Index of the latest confirmed node (cumulative number of
  #    confirmed L2->L1 transactions)
  # - `leaf`: position of the L2->L1 message (`position` field of the associated
  #    `L2ToL1Tx` event). It should be less than `size`
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
  #   connection.
  #
  # Returns:
  # `{:ok, [send, root, proof]}`, where
  #    `proof` - an array of 32-bytes values which are needed to execute messages.
  # `{:error, _}` in case of size less or equal leaf or RPC error
  @spec construct_outbox_proof(
          EthereumJSONRPC.address(),
          non_neg_integer(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, any()} | {:error, :invalid}
  def construct_outbox_proof(_, size, leaf, _) when size <= leaf do
    {:error, :invalid}
  end

  def construct_outbox_proof(node_interface_address, size, leaf, json_rpc_named_arguments) do
    case [
           %{
             contract_address: node_interface_address,
             method_id: @selector_construct_outbox_proof,
             args: [size, leaf]
           }
         ]
         |> EthereumJSONRPC.execute_contract_functions(@node_interface_contract_abi, json_rpc_named_arguments)
         |> List.first() do
      {:ok, proof} ->
        {:ok, proof}

      {:error, err} ->
        Logger.error("node_interface_contract.constructOutboxProof error occurred: #{inspect(err)}")
        {:error, :invalid}
    end
  end

  @doc """
    Check is outgoing L2->L1 message was spent.

    To do that we should invoke `isSpent(uint256 index)` method for
    `Outbox` contract deployed on 1 chain

    ## Parameters
    - `outbox_contract`: address of the Outbox contract (L1 chain)
    - `index`: position (index) of the requested L2->L1 message.
    - `json_l1_rpc_named_arguments`: Configuration parameters for the JSON RPC
        connection for L1 chain.

    ## Returns
    - `true` if message was created, confirmed and claimed on L1 chain.
            Otherwise returns `false`.
  """
  @spec withdrawal_spent?(
          EthereumJSONRPC.address(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: boolean()
  def withdrawal_spent?(outbox_contract, position, json_l1_rpc_named_arguments) do
    case [
           %{
             contract_address: outbox_contract,
             method_id: @selector_is_spent,
             args: [position]
           }
         ]
         |> EthereumJSONRPC.execute_contract_functions(@outbox_contract_abi, json_l1_rpc_named_arguments)
         |> List.first() do
      {:ok, [value]} ->
        value

      {:error, err} ->
        Logger.error("outbox_contract.isSpent(position) error occurred: #{inspect(err)}")
        false
    end
  end
end
