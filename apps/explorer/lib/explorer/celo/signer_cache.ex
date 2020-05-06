defmodule Explorer.Celo.SignerCache do
  @moduledoc """
  Caching the Celo contract ABIs
  """

  use GenServer

  import Explorer.Celo.Util

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  def epoch_signers(epoch, epoch_size, block_number) do
    GenServer.call(__MODULE__, {:fetch, epoch, epoch_size, block_number})
  end

  def fetch_signers(bn) do
    data = call_methods([{:election, "getCurrentValidatorSigners", [], bn - 1}])
    case data["getCurrentValidatorSigners"] do
      {:ok, [lst]} -> lst
      _ -> []
    end
  end

  @impl GenServer
  def handle_call({:fetch, epoch, _epoch_size, block_number}, _, state) do
    case Map.fetch(state, epoch) do
      {:ok, lst} -> {:reply, lst, state}
      _ ->
        lst = fetch_signers(block_number)
        {:reply, lst, Map.put(state, epoch, lst)}
    end
  end

end
