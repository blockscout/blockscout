defmodule APILogger do
  @moduledoc """
  Logger of API ednpoins usage
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
end
