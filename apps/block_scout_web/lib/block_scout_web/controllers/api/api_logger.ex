defmodule BlockScoutWeb.API.APILogger do
  @moduledoc """
  Logger for API endpoints usage
  """
  require Logger

  def log(conn) do
    endpoint =
      if conn.query_string do
        "#{conn.request_path}?#{conn.query_string}"
      else
        conn.request_path
      end

    Logger.debug(endpoint,
      fetcher: :api
    )
  end

  def message(text) do
    Logger.debug(text,
      fetcher: :api
    )
  end
end
