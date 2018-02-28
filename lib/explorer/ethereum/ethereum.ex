defmodule Explorer.Ethereum do
  @client Application.get_env(:explorer, :ethereum)[:backend]

  defmodule API do
    @moduledoc false
    @callback download_balance(String.t()) :: String.t()
  end

  defdelegate download_balance(hash), to: @client

  def decode_integer_field(hex) do
    {"0x", base_16} = String.split_at(hex, 2)
    String.to_integer(base_16, 16)
  end

  def decode_time_field(field) do
    field |> decode_integer_field() |> Timex.from_unix()
  end
end
