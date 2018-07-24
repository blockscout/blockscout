use Mix.Config

variant = System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity"

# Import variant specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "prod/#{variant}.exs"
