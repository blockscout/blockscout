defmodule Indexer.TokenFetcher do
  @moduledoc """
  Fetches information about a token.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Token
  alias Explorer.Chain.Hash.Address
  alias Explorer.SmartContract.Reader
  alias Indexer.BufferedTask

  @behaviour BufferedTask

  @defaults [
    flush_interval: 300,
    max_batch_size: 1,
    max_concurrency: 10,
    init_chunk_size: 1,
    task_supervisor: Indexer.TaskSupervisor
  ]

  @contract_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint8"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "totalSupply",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint256"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    }
  ]

  @doc false
  def child_spec(provided_opts) do
    {state, mergable_opts} = Keyword.pop(provided_opts, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    opts =
      @defaults
      |> Keyword.merge(mergable_opts)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, {__MODULE__, opts}}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      Chain.stream_uncataloged_token_contract_address_hashes(initial_acc, fn address, acc ->
        reducer.(address, acc)
      end)

    acc
  end

  @impl BufferedTask
  def run([token_contract_address], _, json_rpc_named_arguments) do
    case Chain.token_from_address_hash(token_contract_address) do
      {:ok, %Token{cataloged: false} = token} ->
        catalog_token(token, json_rpc_named_arguments)

      {:ok, _} ->
        :ok
    end
  end

  @doc """
  Fetches token data asynchronously given a list of `t:Explorer.Chain.Token.t/0`s.
  """
  @spec async_fetch([Address.t()]) :: :ok
  def async_fetch(token_contract_addresses) do
    BufferedTask.buffer(__MODULE__, token_contract_addresses)
  end

  defp catalog_token(%Token{contract_address_hash: contract_address_hash} = token, json_rpc_named_arguments) do
    contract_functions = %{
      "totalSupply" => [],
      "decimals" => [],
      "name" => [],
      "symbol" => []
    }

    token_contract_results =
      Reader.query_unverified_contract(
        contract_address_hash,
        @contract_abi,
        contract_functions,
        json_rpc_named_arguments: json_rpc_named_arguments
      )

    token_params = format_token_params(token, token_contract_results)

    {:ok, %{tokens: [_]}} = Chain.import(%{tokens: %{params: [token_params], on_conflict: :replace_all}})
    :ok
  end

  def format_token_params(token, token_contract_data) do
    token_contract_data =
      for {function_name, {:ok, [function_data]}} <- token_contract_data, into: %{} do
        {atomized_key(function_name), function_data}
      end

    token
    |> Map.from_struct()
    |> Map.put(:cataloged, true)
    |> Map.merge(token_contract_data)
  end

  defp atomized_key("decimals"), do: :decimals
  defp atomized_key("name"), do: :name
  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("totalSupply"), do: :total_supply
end
