# Tests with everything using `Mox`

use Mix.Config

config :ethereum_jsonrpc, EthereumJSONRPC.Case, json_rpc_named_arguments: [transport: EthereumJSONRPC.Mox]
