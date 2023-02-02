defmodule Indexer.Fetcher.OptimismOutputRoot do
  @moduledoc """
  Fills op_output_roots DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query
  import EthereumJSONRPC, only: [request: 1, json_rpc: 2]

  alias Explorer.Chain.OptimismOutputRoot
  alias Explorer.Repo

  # 32-byte signature of the event OutputProposed(bytes32 indexed outputRoot, uint256 indexed l2OutputIndex, uint256 indexed l2BlockNumber, uint256 l1Timestamp)
  @output_proposed_event "0xa7aaf2512769da4e444e3de247be2564225c2e7a8f74cfe528e46e17d24868e2"

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(fetcher: :optimism_output_root)

    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         optimism_rpc_l1 <- Application.get_env(:indexer, :optimism_rpc_l1),
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_rpc_l1)},
         {:output_oracle_valid, true} <- {:output_oracle_valid, is_address?(env[:output_oracle])},
         start_block_l1 <- parse_integer(env[:start_block_l1]),
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0,
         {last_l1_block_number, last_l1_tx_hash} <- get_last_l1_item(),
         {:start_block_l1_valid, true} <-
           {:start_block_l1_valid, start_block_l1 <= last_l1_block_number || last_l1_block_number == 0},
         json_rpc_named_arguments <- json_rpc_named_arguments(optimism_rpc_l1),
         {:ok, last_l1_tx} <- get_transaction_by_hash(last_l1_tx_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_tx_hash) && is_nil(last_l1_tx)} do
      # INSERT INTO op_output_roots (l2_output_index, l2_block_number, l1_tx_hash, l1_timestamp, l1_block_number, output_root, inserted_at, updated_at) VALUES (1, 1, decode('d6c0399c881c98d4d5fa931bb727d08ebfb86cb37ce380071fa03e59731dffbf', 'hex'), NOW(), 8299683, decode('013d7d16d7ad4fefb61bd95b765c8ceb', 'hex'), NOW(), NOW())
      # {:ok, last_l1_tx_hash} = Explorer.Chain.string_to_transaction_hash("0xd6c0399c881c98d4d5fa931bb727d08ebfb86cb37ce380071fa03e59731dffbe")
      # tx = get_transaction_by_hash(last_l1_tx_hash, json_rpc_named_arguments)
      # Logger.warn("tx = #{inspect(tx)}")

      {:ok, %{output_oracle: env[:output_oracle]}, {:continue, json_rpc_named_arguments}}
    else
      {:start_block_l1_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        :ignore

      {:output_oracle_valid, false} ->
        Logger.error("Output Oracle address is invalid or not defined.")
        :ignore

      {:start_block_l1_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and op_output_roots table.")
        :ignore

      {:error, error_data} ->
        Logger.error("Cannot get last L1 transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")
        :ignore

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check op_output_roots table."
        )

        :ignore

      _ ->
        Logger.error("Output Roots Start Block is invalid or zero.")
        :ignore
    end
  end

  @impl GenServer
  def handle_continue(_json_rpc_named_arguments, state) do
    {:noreply, state}
  end

  defp get_last_l1_item do
    query =
      from(root in OptimismOutputRoot,
        select: {root.l1_block_number, root.l1_tx_hash},
        order_by: [desc: root.l2_output_index],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
  end

  defp get_transaction_by_hash(hash, _json_rpc_named_arguments) when is_nil(hash), do: {:ok, nil}

  defp get_transaction_by_hash(hash, json_rpc_named_arguments) do
    req =
      request(%{
        id: 0,
        method: "eth_getTransactionByHash",
        params: [hash]
      })

    json_rpc(req, json_rpc_named_arguments)
  end

  defp parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_integer_string), do: nil

  defp json_rpc_named_arguments(optimism_rpc_l1) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: optimism_rpc_l1,
        # method_to_url: [],
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ],
      variant: EthereumJSONRPC.Nethermind
    ]
  end

  defp is_address?(value) when is_binary(value) do
    String.match?(value, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  defp is_address?(_value) do
    false
  end
end
