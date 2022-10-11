defmodule Indexer.Celo.WriteOperationHandler do
  @moduledoc "A process to perform operations broadcast from nodes without write access"

  use GenServer

  require Logger
  alias Explorer.Celo.PubSub
  alias Explorer.SmartContract.Solidity.Publisher, as: SmartContractPublisher

  def start_link([init_arg, gen_server_opts]) do
    start_link(init_arg, gen_server_opts)
  end

  def start_link(init_arg, gen_server_opts) do
    gen_server_opts = Keyword.merge(gen_server_opts, name: __MODULE__)

    GenServer.start_link(__MODULE__, init_arg, gen_server_opts)
  end

  @impl true
  def init(_) do
    state = %{}

    {:ok, state, {:continue, :subscribe_to_operations}}
  end

  @impl true
  def handle_continue(:subscribe_to_operations, state) do
    PubSub.subscribe_to_smart_contract_publishing()

    {:noreply, state}
  end

  @impl true
  def handle_info({:smart_contract_publish, address_hash, attributes, msg_id}, state) do
    Logger.info("Got smart contract publish request #{msg_id}")
    SmartContractPublisher.do_create_or_update(address_hash, attributes)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("#{__MODULE__} got unknown message #{msg |> inspect()}")
    {:noreply, state}
  end
end
