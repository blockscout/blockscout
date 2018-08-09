defmodule ExplorerWeb.AsyncHelpers do
  @default_timeout 10_000
  @interval 50

  @moduledoc """
  Helpers used to continuously check assertions until they pass. This
  is super helpful for feature tests when you want to check the database
  for a value that might take some time to reach the server.

  SomePage.submit_a_form
  eventually fn ->
  assert # it exists in the database
  end

  """

  def eventually(func), do: eventually(func, @default_timeout)
  def eventually(func, 0), do: func.()

  def eventually(func, timeout) do
    try do
      func.()
    rescue
      _ ->
        :timer.sleep(@interval)
        eventually(func, max(0, timeout - @interval))
    end
  end
end
