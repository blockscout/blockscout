defmodule EthereumJSONRPC.Case do
  @moduledoc """
  Adds `json_rpc_named_arguments` to context.

  Reads `ETHEREUM_JSONRPC_TRANSPORT` environment variable to determine which module to use `:json_rpc_named_arguments`
  `:transport`:

  * `EthereumJSONRPC.HTTP` - Allow testing of HTTP-only behavior like status codes
  * `EthereumJSONRPC.Mox` - mock, transport neutral responses.  The default for local testing.

  When `ETHEREUM_JSONRPC_TRANSPORT` is `EthereumJSONRPC.HTTP`, then reads `ETHEREUM_JSONRPC_HTTP_URL` environment
  variable to determine `:json_rpc_named_arguments` `:transport_options` `:url`.  Failure to set
  `ETHEREUM_JSONRPC_HTTP_URL` in this case will raise an `ArgumentError`.

  * `EthereumJSONRPC.HTTP.HTTPoison` - HTTP responses from calls to real chain URLs
  * `EthereumJSONRPC.HTTP.Mox` - mock HTTP responses, so can be used for HTTP-only behavior like status codes.

  """

  use ExUnit.CaseTemplate

  require Logger

  setup do
    transport = transport()

    transport_options =
      case transport do
        EthereumJSONRPC.HTTP ->
          [
            http: EthereumJSONRPC.HTTP.Case.http(),
            url: EthereumJSONRPC.HTTP.Case.url(),
            http_options: EthereumJSONRPC.HTTP.Case.http_options()
          ]

        EthereumJSONRPC.WebSocket ->
          pid = start_supervised!({WebSocket.Client, %{url: EthereumJSONRPC.WebSocket.Case.url()}})

          %{pid: pid}

        _ ->
          []
      end

    %{
      json_rpc_named_arguments: [
        transport: transport,
        transport_options: transport_options,
        variant: variant()
      ]
    }
  end

  def log_bad_gateway(under_test, assertions) do
    case under_test.() do
      {:error, {:bad_gateway, url}} -> Logger.error(fn -> ["Bad Gateway to ", url, ".  Check CloudFlare."] end)
      other -> assertions.(other)
    end
  end

  def module(environment_variable, default) do
    alias =
      environment_variable
      |> System.get_env()
      |> Kernel.||(default)

    module = Module.concat([alias])

    with {:error, reason} <- Code.ensure_loaded(module) do
      raise ArgumentError,
            "Could not load `#{environment_variable}` environment variable module (#{module}) due to #{reason}"
    end

    module
  end

  def transport do
    module("ETHEREUM_JSONRPC_TRANSPORT", "EthereumJSONRPC.Mox")
  end

  def variant do
    module("ETHEREUM_JSONRPC_VARIANT", "EthereumJSONRPC.Parity")
  end
end
