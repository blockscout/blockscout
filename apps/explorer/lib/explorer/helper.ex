defmodule Explorer.Helper do
  @moduledoc """
  Common explorer helper
  """
  def parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end
end
