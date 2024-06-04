defmodule EthereumJSONRPC.Logs do
  @moduledoc """
  Collection of logs included in return from
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_gettransactionreceipt).
  """

  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      put_if_present: 3
    ]

  alias EthereumJSONRPC.{Log, Transport}

  @type elixir :: [Log.elixir()]
  @type t :: [Log.t()]

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Log.elixir_to_params/1)
  end

  @spec to_elixir(t) :: elixir
  def to_elixir(logs) when is_list(logs) do
    Enum.map(logs, &Log.to_elixir/1)
  end

  @spec request(
          id :: integer(),
          params ::
            %{
              :from_block => EthereumJSONRPC.tag() | EthereumJSONRPC.block_number(),
              :to_block => EthereumJSONRPC.tag() | EthereumJSONRPC.block_number(),
              optional(:topics) => list(EthereumJSONRPC.hash()),
              optional(:address) => EthereumJSONRPC.address()
            }
            | %{
                :block_hash => EthereumJSONRPC.hash(),
                optional(:topics) => list(EthereumJSONRPC.hash()),
                optional(:address) => EthereumJSONRPC.address()
              }
        ) :: Transport.request()
  def request(id, params) when is_integer(id) do
    EthereumJSONRPC.request(%{
      id: id,
      method: "eth_getLogs",
      params: [to_request_params(params)]
    })
  end

  defp to_request_params(
         %{
           from_block: from_block,
           to_block: to_block
         } = params
       ) do
    %{
      fromBlock: block_number_to_quantity_or_tag(from_block),
      toBlock: block_number_to_quantity_or_tag(to_block)
    }
    |> maybe_add_topics_and_address(params)
  end

  defp to_request_params(%{block_hash: block_hash} = params)
       when is_binary(block_hash) do
    %{
      blockHash: block_hash
    }
    |> maybe_add_topics_and_address(params)
  end

  defp maybe_add_topics_and_address(request_params, params) do
    put_if_present(request_params, params, [
      {:topics, :topics},
      {:address, :address}
    ])
  end

  defp block_number_to_quantity_or_tag(block_number) when is_integer(block_number) do
    integer_to_quantity(block_number)
  end

  defp block_number_to_quantity_or_tag(tag) when tag in ~w(earliest latest pending safe) do
    tag
  end

  def from_responses(responses) when is_list(responses) do
    responses
    |> reduce_responses()
    |> case do
      {:ok, logs} ->
        {
          :ok,
          logs
          |> to_elixir()
          |> elixir_to_params()
        }

      {:error, reasons} ->
        {:error, reasons}
    end
  end

  defp reduce_responses(responses) do
    responses
    |> Enum.reduce(
      {:ok, []},
      fn
        %{result: result}, {:ok, logs}
        when is_list(result) ->
          {:ok, result ++ logs}

        %{result: _}, {:error, _} = error ->
          error

        %{error: reason}, {:ok, _} ->
          {:error, [reason]}

        %{error: reason}, {:error, reasons}
        when is_list(reasons) ->
          {:error, [reason | reasons]}
      end
    )
  end
end
