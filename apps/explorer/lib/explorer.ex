defmodule Explorer do
  @moduledoc """
  Explorer keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  require Logger

  @doc """
  Returns the configured coin for `Explorer`
  """
  def coin do
    Application.get_env(:explorer, :coin)
  end

  def coin_name do
    Application.get_env(:explorer, :coin_name)
  end

  @doc """
  Retrieves the current operational mode of the Explorer application.

  The mode determines which components of the Explorer application are active:
  - `:all` - Both API web server and blockchain indexer run together
  - `:indexer` - Only blockchain indexer modules run without the web server
  - `:api` - Only the web server runs without performing indexing operations

  ## Returns
  - `:all` if both API and indexer components should be active
  - `:indexer` if only the indexer component should be active
  - `:api` if only the API web server component should be active
  """
  @spec mode() :: :all | :indexer | :api
  def mode do
    Application.get_env(:explorer, :mode)
  end
end
