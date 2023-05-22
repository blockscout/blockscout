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
end
