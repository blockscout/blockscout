defmodule Explorer.Vault do
  @moduledoc """
    Module responsible for encrypt/decrypt GenServer initialization
  """
  use Cloak.Vault, otp_app: :explorer

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: decode_env!("ACCOUNT_CLOAK_KEY")}
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    env = if Mix.env() == :test, do: "+fh7IElJfA61+vMMw8rW9SBJFHmhVL1DLpKE22qUJgw=", else: System.get_env(var)

    Base.decode64!(env || "")
  end
end
