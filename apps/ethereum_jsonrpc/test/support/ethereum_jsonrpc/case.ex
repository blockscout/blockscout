defmodule EthereumJSONRPC.Case do
  require Logger

  def log_bad_gateway(under_test, assertions) do
    case under_test.() do
      {:error, {:bad_gateway, url}} -> Logger.error(fn -> ["Bad Gateway to ", url, ".  Check CloudFlare."] end)
      other -> assertions.(other)
    end
  end
end
