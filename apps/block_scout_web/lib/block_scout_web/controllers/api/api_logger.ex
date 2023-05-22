defmodule BlockScoutWeb.API.APILogger do
  @moduledoc """
  Logger for API endpoints usage
  """
  require Logger

  @params [application: :api]

  def message(text) do
    Logger.debug(text, @params)
  end

  def error(error) do
    Logger.error(error, @params)
  end
end
