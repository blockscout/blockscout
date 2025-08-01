defmodule EthereumJSONRPC.Arbitrum do
  @moduledoc """
  Arbitrum specific routines used to fetch and process
  data from the associated JSONRPC endpoint
  """

  import EthereumJSONRPC

  alias EthereumJSONRPC.Arbitrum.Constants.Contracts, as: ArbitrumContracts
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  require Logger
  alias ABI.TypeDecoder

  @typedoc """
  This type describes significant fields which can be extracted from
  the L2ToL1Tx event emitted by ArbSys contract

  * `"message_id"` - The message identifier
  * `"caller"` - `t:EthereumJSONRPC.address/0` of the message initiator
  * `"destination"` - `t:EthereumJSONRPC.address/0` to which the message should be sent after the claiming
  * `"arb_block_number"` - Rollup block number in which the message was initiated
  * `"eth_block_number"` - An associated parent chain block number
  * `"timestamp"` - When the message was initiated
  * `"callvalue"` - Amount of ETH which should be transferred to the `destination` address on message execution
  * `"data"` - Raw calldata which should be set for the execution transaction (usually contains bridge interaction calldata)
  """
  @type l2_to_l1_event :: %{
          :message_id => non_neg_integer(),
          :caller => EthereumJSONRPC.address(),
          :destination => EthereumJSONRPC.address(),
          :arb_block_number => non_neg_integer(),
          :eth_block_number => non_neg_integer(),
          :timestamp => non_neg_integer(),
          :callvalue => non_neg_integer(),
          :data => binary()
        }

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
    call_simple_getters_in_rollup_contract(
      rollup_address,
      [ArbitrumContracts.bridge_selector()],
      json_rpc_named_arguments
    )
  end

  def get_contracts_for_rollup(rollup_address, :inbox_outbox, json_rpc_named_arguments) do
    call_simple_getters_in_rollup_contract(
      rollup_address,
      [ArbitrumContracts.sequencer_inbox_selector(), ArbitrumContracts.outbox_selector()],
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
    |> EthereumJSONRPC.execute_contract_functions(ArbitrumContracts.rollup_contract_abi(), json_rpc_named_arguments)
    |> Enum.zip(method_ids)
    |> Enum.reduce(%{}, fn {{:ok, [response]}, method_id}, retval ->
      Map.put(retval, ArbitrumContracts.atomized_rollup_contract_selector(method_id), response)
    end)
  end

  @doc """
    Retrieves the latest confirmed node index for withdrawals Merkle tree.

    This function fetches an actual confirmed L2->L1 node from the Arbitrum rollup address.
    It invokes contract method `latestConfirmed()` to obtain the required information.

    ## Parameters
    - `rollup_address`: The address of the Arbitrum rollup contract from which
                        information is being retrieved.
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection (L1 chain).

    ## Returns
    - {:ok, number} - where `number` is a positive integer representing the latest confirmed node index
      {:error, _} - in case of any failure
  """
  @spec get_latest_confirmed_node_index(
          EthereumJSONRPC.address(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, non_neg_integer()} | {:error, any()}
  def get_latest_confirmed_node_index(rollup_address, json_rpc_l1_named_arguments) do
    case read_contract(
           rollup_address,
           ArbitrumContracts.latest_confirmed_selector(),
           [],
           ArbitrumContracts.rollup_contract_abi(),
           json_rpc_l1_named_arguments
         ) do
      {:ok, [value]} ->
        {:ok, value}

      {:error, err} ->
        Logger.error("rollup_contract.latestConfirmed() error occurred: #{inspect(err)}")
        {:error, err}
    end
  end

  @doc """
    Retrieves the L1 block number in which the rollup node with the provided index was created.

    This function fetches node information by specified node index
    It invokes Rollup contract method `getNode(nodeNum)` to obtain the required data.

    ## Parameters
    - `rollup_address`: The address of the Arbitrum rollup contract from which
                      information is being retrieved.
    - `node_index`: index of the requested rollup node
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection (L1).

    ## Returns
    - {:ok, number} - where `number` is block number (L1) in which the rollup node was created
      {:error, _} - in case of any failure
  """
  @spec get_node_creation_block_number(
          EthereumJSONRPC.address(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, non_neg_integer()} | {:error, any()}
  def get_node_creation_block_number(rollup_address, node_index, json_rpc_l1_named_arguments) do
    case read_contract(
           rollup_address,
           ArbitrumContracts.get_node_selector(),
           [node_index],
           ArbitrumContracts.rollup_contract_abi(),
           json_rpc_l1_named_arguments
         ) do
      # `createdAtBlock` property of node tuple
      {:ok, [fields]} -> {:ok, fields |> Kernel.elem(10)}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
    Parses an L2-to-L1 event, extracting relevant information from the event's data.

    This function takes an L2ToL1Tx event emitted by ArbSys contract and parses its fields
    to extract needed message properties.

    ## Parameters
    - `event`: A log entry representing an L2-to-L1 message event.

    ## Returns
    - A map describing the L2-to-L1 message
  """
  @spec l2_to_l1_event_parse(%{
          :data => binary(),
          :second_topic => binary(),
          :fourth_topic => binary(),
          optional(atom()) => any()
        }) :: l2_to_l1_event()
  def l2_to_l1_event_parse(event) do
    [
      caller,
      arb_block_number,
      eth_block_number,
      timestamp,
      callvalue,
      data
    ] =
      event.data
      |> decode_data(ArbitrumEvents.l2_to_l1_unindexed_params())

    position =
      case quantity_to_integer(event.fourth_topic) do
        nil -> 0
        number -> number
      end

    caller_string = value_to_address(caller)
    destination_string = value_to_address(event.second_topic)

    %{
      :message_id => position,
      :caller => caller_string,
      :destination => destination_string,
      :arb_block_number => arb_block_number,
      :eth_block_number => eth_block_number,
      :timestamp => timestamp,
      :callvalue => callvalue,
      :data => data
    }
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

  @doc """
    Casts a value into an Ethereum address (hex-string, 0x-prefixed, not checksummed).

    ## Parameters
      - value: `0x` prefixed hex string or byte array to be cast into an Ethereum address.

    ## Returns
      - A string representing the Ethereum address in hex format, prefixed with '0x'
  """
  @spec value_to_address(binary()) :: String.t()
  def value_to_address(value) do
    hex =
      cond do
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

  @doc """
    Calculates the proof needed to claim an L2->L1 message.

    Calls the `constructOutboxProof` method of the Node Interface contract on the
    rollup to obtain the data needed for an L2->L1 message claim.

    ## Parameters
    - `node_interface_address`: Address of the node interface contract
    - `size`: Index of the latest confirmed node (cumulative number of confirmed
      L2->L1 transactions)
    - `leaf`: Position of the L2->L1 message (`position` field of the associated
      `L2ToL1Tx` event). Must be less than `size`
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
      connection

    ## Returns
    - `{:ok, [send, root, proof]}` where `proof` is an array of 32-byte values
      needed to execute messages
    - `{:error, _}` if size is less than or equal to leaf, or if an RPC error
      occurs
  """
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
    case read_contract(
           node_interface_address,
           ArbitrumContracts.construct_outbox_proof_selector(),
           [size, leaf],
           ArbitrumContracts.node_interface_contract_abi(),
           json_rpc_named_arguments
         ) do
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
    - `{:ok, is_spent}`, where `is_spent` equals `true` if message was created, confirmed and claimed on L1
      `{:error, _}` in case of any failure
  """
  @spec withdrawal_spent?(
          EthereumJSONRPC.address(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, boolean()} | {:error, any()}
  def withdrawal_spent?(outbox_contract, position, json_l1_rpc_named_arguments) do
    case read_contract(
           outbox_contract,
           ArbitrumContracts.is_spent_selector(),
           [position],
           ArbitrumContracts.outbox_contract_abi(),
           json_l1_rpc_named_arguments
         ) do
      {:ok, [value]} ->
        {:ok, value}

      {:error, err} ->
        Logger.error("outbox_contract.isSpent(position) error occurred: #{inspect(err)}")
        {:error, err}
    end
  end

  # Read a specified contract by provided selector and parameters from the RPC node
  #
  # ## Parameters
  # - `contract_address`: The address of the contract to interact with.
  # - `contract_selector`: Selector in form of 4-byte hex-string without 0x prefix
  # - `call_arguments`: List of the contract function parameters ([] if there are no parameters for the functions)
  # - `contract_abi`: The contract ABI which contains invoked function description
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - `{:ok, term()}` in case of success call or `{:error, String.t()}` on error
  @spec read_contract(
          EthereumJSONRPC.address(),
          String.t(),
          [any()],
          [map()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: EthereumJSONRPC.Contract.call_result()
  defp read_contract(contract_address, contract_selector, call_arguments, contract_abi, json_rpc_named_arguments) do
    [
      %{
        contract_address: contract_address,
        method_id: contract_selector,
        args: call_arguments
      }
    ]
    |> EthereumJSONRPC.execute_contract_functions(contract_abi, json_rpc_named_arguments)
    |> List.first()
  end
end
