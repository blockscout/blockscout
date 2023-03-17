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

  defp convert_to_ms(number, "s"), do: :timer.seconds(number)
  defp convert_to_ms(number, "m"), do: :timer.minutes(number)
  defp convert_to_ms(number, "h"), do: :timer.hours(number)
end
