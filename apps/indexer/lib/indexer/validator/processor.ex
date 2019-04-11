defmodule Indexer.Validator.Processor do
  @moduledoc """
  module to periodically retrieve and update metadata belonging to validators
  """
  use GenServer
  alias Indexer.Validator.{Importer, Retriever}
  require Logger

  def start_link([arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl true
  def init(%{subscribe_named_arguments: subscribe_named_arguments})
      when is_list(subscribe_named_arguments) do
    send(self(), :import)
    {:ok, %{subscription: nil}, {:continue, {:init, subscribe_named_arguments}}}
  end

  @impl GenServer
  def handle_continue({:init, subscribe_named_arguments}, state) when is_list(subscribe_named_arguments) do
    topic = Base.encode16(:keccakf1600.hash(:sha3_256, "InitiateChange(bytes32,address[])"), case: :lower)

    case EthereumJSONRPC.subscribe("logs", [%{"fromBlock" => "latest", "toBlock" => "latest"}], subscribe_named_arguments) do
      {:ok, subscription} ->
        {:noreply, %{subscription: subscription, topic: topic}}

      {:error, _reason} ->
        Logger.error("Failed to subscribe to logs through websocket")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:import, %{subscription: subscribtion} = state) do
    fetch_validators()

    if is_nil(subscribtion), do: reschedule()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({_, {:ok, msg}}, %{topic: topic} = state) do
    with {%ABI.FunctionSelector{}, fields} <- decode_event(msg, topic),
      {:ok, addresses} <- get_value(fields, "newSet")
    do
      addresses
      |> Retriever.fetch_validators_metadata()
      |> Importer.import_metadata()
    end

    {:noreply, state}
  end

  defp fetch_validators() do
    Retriever.fetch_data()
    |> Importer.import_metadata()
  end

  defp reschedule do
    Process.send_after(self(), :import, :timer.seconds(5))
  end

  defp decode_event(msg, topic) do
    case msg do
      %{topics: ["0x" <> topic1, "0x" <> topic2], data: data} when topic == topic1 ->
        topic1_decoded = Base.decode16!(topic1, case: :lower)
        topic2_decoded = Base.decode16!(topic2, case: :lower)

        contract_abi("validators.json")
        |> ABI.parse_specification(include_events?: true)
        |> ABI.Event.find_and_decode(topic1_decoded, topic2_decoded, nil, nil, data)

      _ ->
        {:error, :invalid_event}
    end
  end

  defp get_value(fields, name) do
    values =
      fields
      |> Enum.map(fn {name, _type, _indexed, value} -> {name, value} end)
      |> Enum.into(%{})

    case Map.get(values, name) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  defp contract_abi(file_name) do
    :indexer
    |> Application.app_dir("priv/validator_contracts_abi/#{file_name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
