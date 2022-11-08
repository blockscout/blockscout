defmodule Explorer.Health do
  @moduledoc """
  Check various health attributes of the application
  """

  alias Ecto.Adapters.SQL
  alias Explorer.Repo.Local, as: Repo

  @doc """
  Check if app is ready
  """
  def ready? do
    database_connection_alive?() &&
      fullnode_ready?()
  end

  @doc """
  Check if app is alive and working
  """
  def alive? do
    database_connection_alive?() &&
      fullnode_connection_alive?()
  end

  @doc """
  Check if app can connect to the fullnode and
  the latest block is fresh
  """
  def fullnode_ready? do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    healthy_blocks_period = Application.get_env(:explorer, :healthy_blocks_period)

    case EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments) do
      {:ok, number} ->
        case EthereumJSONRPC.fetch_blocks_by_range(number..number, json_rpc_named_arguments) do
          {:ok, blocks} ->
            diff = DateTime.diff(DateTime.utc_now(), Enum.at(blocks.blocks_params, 0).timestamp) * 1000
            diff <= healthy_blocks_period

          {:error, _} ->
            false
        end

      {:error, _} ->
        false
    end
  end

  @doc """
  Check if app can connect to the fullnode
  """
  def fullnode_connection_alive? do
    case EthereumJSONRPC.fetch_net_version(Application.get_env(:explorer, :json_rpc_named_arguments)) do
      {:ok, _} ->
        true

      {:error, _} ->
        false
    end
  end

  @doc """
  Check if DB connection is alive, by making a simple
  request
  """
  def database_connection_alive? do
    SQL.query!(Repo, "SELECT 1")
    true
  rescue
    _e -> false
  end
end
