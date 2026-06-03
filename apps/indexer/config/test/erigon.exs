# SPDX-License-Identifier: LicenseRef-Blockscout
import Config

config :indexer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.Mox,
    transport_options: [],
    variant: EthereumJSONRPC.Erigon
  ]
