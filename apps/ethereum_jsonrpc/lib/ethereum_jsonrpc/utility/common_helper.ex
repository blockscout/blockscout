defmodule EthereumJSONRPC.Utility.CommonHelper do
  @moduledoc """
    Common helper functions
  """

  # converts duration like "5s", "2m", "1h5m" to milliseconds
  @duration_regex ~r/(\d+)([smhSMH]?)/
  def parse_duration(duration) do
    case Regex.scan(@duration_regex, duration) do
      [] ->
        {:error, :invalid_format}

      parts ->
        Enum.reduce(parts, 0, fn [_, number, granularity], acc ->
          acc + convert_to_ms(String.to_integer(number), String.downcase(granularity))
        end)
    end
  end

  @doc """
  Puts value under nested key in keyword.
  Similar to `Kernel.put_in/3` but inserts values in the middle if they're missing
  """
  @spec put_in_keyword_nested(Keyword.t(), [atom()], any()) :: Keyword.t()
  def put_in_keyword_nested(keyword, [last_path], value) do
    Keyword.put(keyword || [], last_path, value)
  end

  def put_in_keyword_nested(keyword, [nearest_path | rest_path], value) do
    Keyword.put(keyword || [], nearest_path, put_in_keyword_nested(keyword[nearest_path], rest_path, value))
  end

  defp convert_to_ms(number, "s"), do: :timer.seconds(number)
  defp convert_to_ms(number, "m"), do: :timer.minutes(number)
  defp convert_to_ms(number, "h"), do: :timer.hours(number)
end
