defmodule AccountLogger do
  @moduledoc """
  Logger of API ednpoins usage
  """
  require Logger

  def debug(msg) do
    Logger.debug(msg, fetcher: :account)
  end

  def info(msg) do
    Logger.info(msg, fetcher: :account)
  end
end
