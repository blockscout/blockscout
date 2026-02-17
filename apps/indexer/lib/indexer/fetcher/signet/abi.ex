defmodule Indexer.Fetcher.Signet.Abi do
  @moduledoc """
  ABI definitions for Signet contracts.

  ABIs are sourced from @signet-sh/sdk npm package and stored as JSON files
  in apps/explorer/priv/contracts_abi/signet/.

  To update ABIs:
    cd tools/signet-sdk && npm run extract

  ## Event Signatures (from SDK)

  RollupOrders contract:
  - Order(uint256 deadline, (address token, uint256 amount)[] inputs, (address token, uint256 amount, address recipient, uint32 chainId)[] outputs)
  - Filled((address token, uint256 amount, address recipient, uint32 chainId)[] outputs)
  - Sweep(address indexed recipient, address indexed token, uint256 amount)

  HostOrders contract:
  - Filled((address token, uint256 amount, address recipient, uint32 chainId)[] outputs)
  """

  require Logger

  # Compute event topic hashes at compile time
  # These match the event signatures from @signet-sh/sdk rollupOrdersAbi

  # Order(uint256,(address,uint256)[],(address,uint256,address,uint32)[])
  @order_event_signature "Order(uint256,(address,uint256)[],(address,uint256,address,uint32)[])"

  # Filled((address,uint256,address,uint32)[])
  @filled_event_signature "Filled((address,uint256,address,uint32)[])"

  # Sweep(address,address,uint256) - recipient and token are indexed
  @sweep_event_signature "Sweep(address,address,uint256)"

  @doc """
  Returns the keccak256 topic hash for the Order event.
  """
  @spec order_event_topic() :: binary()
  def order_event_topic do
    "0x" <> Base.encode16(ExKeccak.hash_256(@order_event_signature), case: :lower)
  end

  @doc """
  Returns the keccak256 topic hash for the Filled event.
  """
  @spec filled_event_topic() :: binary()
  def filled_event_topic do
    "0x" <> Base.encode16(ExKeccak.hash_256(@filled_event_signature), case: :lower)
  end

  @doc """
  Returns the keccak256 topic hash for the Sweep event.
  """
  @spec sweep_event_topic() :: binary()
  def sweep_event_topic do
    "0x" <> Base.encode16(ExKeccak.hash_256(@sweep_event_signature), case: :lower)
  end

  @doc """
  Returns all event topics for the RollupOrders contract.
  """
  @spec rollup_orders_event_topics() :: [binary()]
  def rollup_orders_event_topics do
    [order_event_topic(), filled_event_topic(), sweep_event_topic()]
  end

  @doc """
  Returns all event topics for the HostOrders contract.
  Only the Filled event is relevant from the host chain.
  """
  @spec host_orders_event_topics() :: [binary()]
  def host_orders_event_topics do
    [filled_event_topic()]
  end

  @doc """
  Load a Signet contract ABI from the priv directory.

  ## Examples

      iex> Abi.load_abi("rollup_orders")
      {:ok, [...]}

      iex> Abi.load_abi("nonexistent")
      {:error, :not_found}
  """
  @spec load_abi(String.t()) :: {:ok, list()} | {:error, atom()}
  def load_abi(contract_name) do
    path = abi_path(contract_name)

    case File.read(path) do
      {:ok, content} ->
        {:ok, Jason.decode!(content)}

      {:error, :enoent} ->
        Logger.warning("Signet ABI not found: #{path}")
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to load Signet ABI #{contract_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get the file path for a Signet contract ABI.
  """
  @spec abi_path(String.t()) :: String.t()
  def abi_path(contract_name) do
    :explorer
    |> Application.app_dir("priv/contracts_abi/signet/#{contract_name}.json")
  end

  @doc """
  Returns the event signature string for the Order event.
  """
  @spec order_event_signature() :: String.t()
  def order_event_signature, do: @order_event_signature

  @doc """
  Returns the event signature string for the Filled event.
  """
  @spec filled_event_signature() :: String.t()
  def filled_event_signature, do: @filled_event_signature

  @doc """
  Returns the event signature string for the Sweep event.
  """
  @spec sweep_event_signature() :: String.t()
  def sweep_event_signature, do: @sweep_event_signature
end
