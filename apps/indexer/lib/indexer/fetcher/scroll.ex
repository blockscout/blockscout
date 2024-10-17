defmodule Indexer.Fetcher.Scroll do
  @moduledoc """
    A module to define common Scroll configuration parameters.
  """

  @doc """
    Returns L1 RPC URL for Scroll modules.
    Returns `nil` if not defined.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Application.get_all_env(:indexer)[__MODULE__][:rpc]
  end
end
