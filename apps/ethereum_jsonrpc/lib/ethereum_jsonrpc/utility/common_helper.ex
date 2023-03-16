defmodule EthereumJSONRPC.Utility.CommonHelper do
  @moduledoc """
    Common helper functions
  """

  # converts duration like "5s", "2m" to milliseconds
  @duration_regex ~r/^(\d+)([smh]{1})$/
  def parse_duration(duration) do
    case Regex.run(@duration_regex, duration) do
      [_, number, granularity] ->
        number
        |> String.to_integer()
        |> convert_to_ms(granularity)

      _ ->
        {:error, :invalid_format}
    end
  end

  defp convert_to_ms(number, "s"), do: :timer.seconds(number)
  defp convert_to_ms(number, "m"), do: :timer.minutes(number)
  defp convert_to_ms(number, "h"), do: :timer.hours(number)
end
