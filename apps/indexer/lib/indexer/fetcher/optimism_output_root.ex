defmodule Indexer.Fetcher.OptimismOutputRoot do
  @moduledoc """
  Fills op_output_roots DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  # import Ecto.Query

  # alias Explorer.Chain.OptimismOutputRoot
  # alias Explorer.Repo

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
  def init(args) do
    Logger.metadata(fetcher: :optimism_output_root)

    env = Application.get_all_env(:indexer)[__MODULE__]
    optimism_rpc_l1 = Application.get_env(:indexer, :optimism_rpc_l1)

    l1_json_rpc_named_arguments = l1_json_rpc_named_arguments(optimism_rpc_l1)
    l2_json_rpc_named_arguments = args[:json_rpc_named_arguments]

    start_block_l1 = parse_integer(env[:start_block_l1])

    with {:start_block_l1_undefined, false} <- {:start_block_l1_undefined, is_nil(env[:start_block_l1])},
         {:rpc_l1_undefined, false} <- {:rpc_l1_undefined, is_nil(optimism_rpc_l1)},
         {:output_oracle_valid, true} <- {:output_oracle_valid, is_address?(env[:output_oracle])},
         false <- is_nil(start_block_l1),
         true <- start_block_l1 > 0 do
      {:ok, %{}}
    else
      {:start_block_l1_undefined, true} ->
        # the process shoudln't start if the start block is not defined
        :ignore

      {:rpc_l1_undefined, true} ->
        Logger.error("L1 RPC URL is not defined")
        :ignore

      {:output_oracle_valid, false} ->
        Logger.error("Output Oracle address is invalid or not defined")
        :ignore

      _ ->
        Logger.error("Output Roots Start Block is invalid or zero")
        :ignore
    end
  end

  defp parse_integer(integer_string) when is_binary(integer_string) do
    case Integer.parse(integer_string) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp parse_integer(_integer_string), do: nil

  defp l1_json_rpc_named_arguments(optimism_rpc_l1) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: optimism_rpc_l1,
        method_to_url: [],
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
