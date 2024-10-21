defmodule Indexer.Fetcher.Scroll.Helper do
  @moduledoc """
    A module to define common Scroll indexer functions.
  """

  @doc """
    Returns L1 RPC URL for Scroll modules.
    Returns `nil` if not defined.
  """
  @spec l1_rpc_url() :: binary() | nil
  def l1_rpc_url do
    Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll][:rpc]
  end
end
