defmodule EthereumJSONRPC.Receipts do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_gettransactionreceipt) from batch
  requests.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import EthereumJSONRPC, only: [json_rpc: 2, quantity_to_integer: 1]

  alias EthereumJSONRPC.{Logs, Receipt}
  alias EthereumJSONRPC.Receipts.{ByBlockNumber, ByTransactionHash}

  @type elixir :: [Receipt.elixir()]
  @type t :: [Receipt.t()]

  @doc """
  Extracts logs from `t:elixir/0`

      iex> EthereumJSONRPC.Receipts.elixir_to_logs([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => 37,
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => 50450,
      ...>     "gasUsed" => 50450,
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => 37,
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => 0,
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => 0,
      ...>         "transactionLogIndex" => 0
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> ])
      [
        %{
          "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
          "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          "blockNumber" => 37,
          "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
          "logIndex" => 0,
          "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
          "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          "transactionIndex" => 0,
          "transactionLogIndex" => 0
        }
      ]

  """
  @spec elixir_to_logs(elixir) :: Logs.elixir()
  def elixir_to_logs(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Receipt.elixir_to_logs/1)
  end

  @doc """
  Converts each element of `t:elixir/0` to params used by `Explorer.Chain.Receipt.changeset/2`.

      iex> EthereumJSONRPC.Receipts.elixir_to_params([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => 37,
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => 50450,
      ...>     "gasUsed" => 50450,
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => 37,
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => 0,
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => 0,
      ...>         "transactionLogIndex" => 0
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> ])
      [
        %{
          created_contract_address_hash: nil,
          cumulative_gas_used: 50450,
          gas_used: 50450,
          status: :ok,
          transaction_hash: "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          transaction_index: 0,\
  #{case @chain_type do
    :ethereum -> """
            blob_gas_price: 0,\
            blob_gas_used: 0\
      """
    :optimism -> """
        l1_fee: 0,\
        l1_fee_scalar: 0,\
        l1_gas_price: 0,\
        l1_gas_used: 0\
      """
    :scroll -> """
        l1_fee: 0\
      """
    :arbitrum -> """
        gas_used_for_l1: nil\
      """
    _ -> ""
  end}
        }
      ]

  """
  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Receipt.elixir_to_params/1)
  end

  @doc """
    Fetches transaction receipts and logs, converting them to a format ready for
    database import.

    Makes batch JSON-RPC requests to retrieve receipts for multiple transactions
    sequentially. Processes the raw receipt data into standardized format suitable
    for database import.

    ## Parameters
    - `request_origins`: A list of transaction parameter maps
    - `json_rpc_named_arguments`: Configuration for JSON-RPC connection

    ## Returns
    - `{:ok, %{logs: list(), receipts: list()}}` - Successfully processed receipts
      and logs ready for database import
    - `{:error, reason}` - Error occurred during fetch or processing
  """
  @spec fetch(
          [
            %{
              required(:gas) => non_neg_integer(),
              required(:hash) => EthereumJSONRPC.hash(),
              optional(atom) => any
            }
          ],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, %{logs: list(), receipts: list()}} | {:error, reason :: term()}
  def fetch(transactions_params, json_rpc_named_arguments)

  def fetch([], _json_rpc_named_arguments), do: {:ok, %{logs: [], receipts: []}}

  def fetch(transactions_params, json_rpc_named_arguments) when is_list(transactions_params) do
    {requests, id_to_transaction_params} =
      transactions_params
      |> Stream.with_index()
      |> Enum.reduce({[], %{}}, fn {%{hash: transaction_hash} = transaction_params, id},
                                   {acc_requests, acc_id_to_transaction_params} ->
        requests = [ByTransactionHash.request(id, transaction_hash) | acc_requests]
        id_to_transaction_params = Map.put(acc_id_to_transaction_params, id, transaction_params)
        {requests, id_to_transaction_params}
      end)

    request_and_parse(requests, id_to_transaction_params, json_rpc_named_arguments)
  end

  @doc """
    Fetches transaction receipts and logs, converting them to a format ready for
    database import.

    Makes batch JSON-RPC requests to retrieve receipts for multiple block numbers
    sequentially. Processes the raw receipt data into standardized format suitable
    for database import.

    ## Parameters
    - `block_numbers`: A list of block numbers
    - `json_rpc_named_arguments`: Configuration for JSON-RPC connection

    ## Returns
    - `{:ok, %{logs: list(), receipts: list()}}` - Successfully processed receipts
      and logs ready for database import
    - `{:error, reason}` - Error occurred during fetch or processing
  """
  @spec fetch_by_block_numbers(
          [EthereumJSONRPC.block_number() | EthereumJSONRPC.quantity()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) ::
          {:ok, %{logs: list(), receipts: list()}} | {:error, reason :: term()}
  def fetch_by_block_numbers(block_numbers, json_rpc_named_arguments)

  def fetch_by_block_numbers([], _json_rpc_named_arguments), do: {:ok, %{logs: [], receipts: []}}

  def fetch_by_block_numbers(block_numbers, json_rpc_named_arguments) when is_list(block_numbers) do
    requests =
      block_numbers
      |> Enum.map(&ByBlockNumber.request(%{id: &1, number: &1}))

    request_and_parse(requests, block_numbers, json_rpc_named_arguments)
  end

  # Executes a batch JSON-RPC request to retrieve and process receipts.
  #
  # This function handles the request and response processing for both transaction
  # and block number based receipt retrieval. It converts the raw responses into
  # data structures suitable for database import.
  #
  # ## Parameters
  # - `requests`: A list of JSON-RPC requests to be executed.
  # - `elements_with_ids`: A map or a list enumerating elements with request IDs
  # - `json_rpc_named_arguments`: Configuration for JSON-RPC connection.
  #
  # ## Returns
  # - `{:ok, %{logs: list(), receipts: list()}}` - Successfully processed receipts
  #   and logs ready for database import.
  # - `{:error, reason}` - Error occurred during fetch or processing.
  @spec request_and_parse(
          [EthereumJSONRPC.Transport.request()],
          %{EthereumJSONRPC.request_id() => %{required(:gas) => non_neg_integer(), optional(atom()) => any()}}
          | [EthereumJSONRPC.request_id()],
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:ok, %{logs: list(), receipts: list()}} | {:error, reason :: term()}
  defp request_and_parse(requests, elements_with_ids, json_rpc_named_arguments) do
    with {:ok, raw_responses} <- json_rpc(requests, json_rpc_named_arguments),
         {:ok, fizzy_responses} <- process_responses(raw_responses, elements_with_ids) do
      elixir_receipts = to_elixir(fizzy_responses)

      elixir_logs = elixir_to_logs(elixir_receipts)
      receipts = elixir_to_params(elixir_receipts)
      logs = Logs.elixir_to_params(elixir_logs)

      {:ok, %{logs: logs, receipts: receipts}}
    end
  end

  @doc """
  Converts stringly typed fields to native Elixir types.

      iex> EthereumJSONRPC.Receipts.to_elixir([
      ...>   %{
      ...>     "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>     "blockNumber" => "0x25",
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => "0xc512",
      ...>     "gasUsed" => "0xc512",
      ...>     "logs" => [
      ...>       %{
      ...>         "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
      ...>         "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
      ...>         "blockNumber" => "0x25",
      ...>         "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
      ...>         "logIndex" => "0x0",
      ...>         "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
      ...>         "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>         "transactionIndex" => "0x0",
      ...>         "transactionLogIndex" => "0x0"
      ...>       }
      ...>     ],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => "0x1",
      ...>     "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> ])
      [
        %{
          "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
          "blockNumber" => 37,
          "contractAddress" => nil,
          "cumulativeGasUsed" => 50450,
          "gasUsed" => 50450,
          "logs" => [
            %{
              "address" => "0x8bf38d4764929064f2d4d3a56520a76ab3df415b",
              "blockHash" => "0xf6b4b8c88df3ebd252ec476328334dc026cf66606a84fb769b3d3cbccc8471bd",
              "blockNumber" => 37,
              "data" => "0x000000000000000000000000862d67cb0773ee3f8ce7ea89b328ffea861ab3ef",
              "logIndex" => 0,
              "topics" => ["0x600bcf04a13e752d1e3670a5a9f1c21177ca2a93c6f5391d4f1298d098097c22"],
              "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
              "transactionIndex" => 0,
              "transactionLogIndex" => 0
            }
          ],
          "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000200000000000000000000020000000000000000200000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "root" => nil,
          "status" => :ok,
          "transactionHash" => "0x53bd884872de3e488692881baeec262e7b95234d3965248c39fe992fffd433e5",
          "transactionIndex" => 0
        }
      ]

  """
  @spec to_elixir(t) :: elixir
  def to_elixir(receipts) when is_list(receipts) do
    Enum.map(receipts, &Receipt.to_elixir/1)
  end

  # Modifies a JSON-RPC response.
  #
  # ## Parameters
  # - `response`: The JSON-RPC response containing either a receipt, list of receipts,
  #   nil result, or error
  # - `elements_with_ids`: A map or a list enumerating elements with request IDs
  #
  # ## Returns
  # - `{:ok, map_or_list}` a map or list of maps representing receipts with gas
  #   information added for successful receipt responses
  # - `{:error, %{code: -32602, data: data, message: "Not Found"}}` for nil results
  # - `{:error, reason}` with transaction data added for error responses
  @spec modify_response(
          EthereumJSONRPC.Transport.response(),
          %{
            EthereumJSONRPC.request_id() => %{
              :gas => non_neg_integer(),
              optional(atom()) => any()
            }
          }
          | [EthereumJSONRPC.request_id()]
        ) :: {:ok, map() | [map()]} | {:error, %{:data => any(), optional(any()) => any()}}
  defp modify_response(response, elements_with_ids)

  defp modify_response(%{id: id, result: nil}, id_to_transaction_params) when is_map(id_to_transaction_params) do
    data = Map.fetch!(id_to_transaction_params, id)
    {:error, %{code: -32602, data: data, message: "Not Found"}}
  end

  defp modify_response(%{id: id, result: nil}, request_ids) when is_list(request_ids) do
    {:error, %{code: -32602, data: id, message: "Not Found"}}
  end

  defp modify_response(%{id: id, result: receipt}, id_to_transaction_params) when is_map(id_to_transaction_params) do
    %{gas: gas} = Map.fetch!(id_to_transaction_params, id)

    # gas from the transaction is needed for pre-Byzantium derived status
    {:ok, Map.put(receipt, "gas", gas)}
  end

  # The list of receipts is returned by `eth_getBlockReceipts`
  defp modify_response(%{id: id, result: receipts}, request_ids) when is_list(receipts) and is_list(request_ids) do
    receipts_with_gas =
      Enum.map(receipts, fn receipt ->
        check_equivalence(Map.fetch!(receipt, "blockNumber"), id)
        Map.put(receipt, "gas", 0)
      end)

    {:ok, receipts_with_gas}
  end

  defp modify_response(%{id: id, error: reason}, id_to_transaction_params) when is_map(id_to_transaction_params) do
    data = Map.fetch!(id_to_transaction_params, id)
    annotated_reason = Map.put(reason, :data, data)
    {:error, annotated_reason}
  end

  defp modify_response(%{id: id, error: reason}, request_ids) when is_list(request_ids) do
    annotated_reason = Map.put(reason, :data, id)
    {:error, annotated_reason}
  end

  # Verifies that a block number matches the request ID
  @spec check_equivalence(EthereumJSONRPC.block_number() | EthereumJSONRPC.quantity(), EthereumJSONRPC.request_id()) ::
          true
  defp check_equivalence(block_number, id) when is_integer(block_number) and is_integer(id) do
    true = block_number == id
  end

  defp check_equivalence(block_number, id) when is_binary(block_number) and is_integer(id) do
    true = quantity_to_integer(block_number) == id
  end

  # Processes a batch of JSON-RPC responses by performing a series of transformations
  # to standardize their structure.
  #
  # Ensures that each response has a valid ID, assigning unmatched IDs to responses
  # with missing IDs. Adjusts each response by extending error data with relevant
  # request details or adding extra fields when needed. Combines individual
  # responses into a unified format, returning either a successful or error tuple
  # with a list of responses.
  #
  # ## Parameters
  # - `responses`: List of JSON-RPC responses for transaction receipts
  # - `id_to_transaction_params`: A map or a list enumerating elements with request IDs
  #
  # ## Returns
  # - `{:ok, receipts}` with list of successfully processed receipts
  # - `{:error, reasons}` with list of error reasons if any receipt failed
  @spec process_responses(
          EthereumJSONRPC.Transport.batch_response(),
          %{
            EthereumJSONRPC.request_id() => %{
              :gas => non_neg_integer(),
              optional(atom()) => any()
            }
          }
          | [EthereumJSONRPC.request_id()]
        ) :: {:ok, [map()]} | {:error, [map()]}
  defp process_responses(responses, elements_with_ids) when is_list(responses) do
    responses
    |> EthereumJSONRPC.sanitize_responses(elements_with_ids)
    |> Stream.map(&modify_response(&1, elements_with_ids))
    |> Enum.reduce({:ok, []}, &harmonize_responses(&1, &2))
  end

  # Combines receipt responses while preserving error state. Successfully processed
  # receipts are accumulated in a list. If any error occurs, switches to error mode and
  # collects error reasons, discarding all successful receipts.
  #
  # ## Parameters
  # - `response`: Current response tuple containing either:
  #   - `{:ok, map_or_list}`: Successfully processed receipt or list of receipts
  #   - `{:error, reason}`: Error with reason
  # - `acc`: Accumulator tuple containing either:
  #   - `{:ok, raw_receipts}`: List of successful receipts
  #   - `{:error, reasons}`: List of error reasons
  #
  # ## Returns
  # - `{:ok, receipts}`: List with new receipt prepended if no errors
  # - `{:error, reasons}`: List of error reasons if any error occurred
  @spec harmonize_responses(
          {:ok, map() | [map()]} | {:error, map()},
          {:ok, [map()]} | {:error, [map()]}
        ) :: {:ok, [map()]} | {:error, [map()]}
  defp harmonize_responses(response, acc)

  defp harmonize_responses({:ok, raw_modified_receipt}, {:ok, raw_receipts})
       when is_map(raw_modified_receipt) and is_list(raw_receipts),
       do: {:ok, [raw_modified_receipt | raw_receipts]}

  # The list of receipts is returned by `eth_getBlockReceipts`
  defp harmonize_responses({:ok, raw_modified_receipts}, {:ok, raw_receipts})
       when is_list(raw_modified_receipts) and is_list(raw_receipts),
       do: {:ok, raw_modified_receipts ++ raw_receipts}

  defp harmonize_responses({:ok, _}, {:error, _} = error), do: error
  defp harmonize_responses({:error, reason}, {:ok, _}), do: {:error, [reason]}
  defp harmonize_responses({:error, reason}, {:error, reasons}) when is_list(reasons), do: {:error, [reason | reasons]}
end
