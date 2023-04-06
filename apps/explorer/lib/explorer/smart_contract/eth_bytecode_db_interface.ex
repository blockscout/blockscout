defmodule Explorer.SmartContract.EthBytecodeDBInterface do
  @moduledoc """
    Adapter for interaction with https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db
  """

  def search_contract(%{"bytecode" => _, "bytecodeType" => _} = body) do
    http_post_request(bytecode_search_sources_url(), body)
  end

  def process_verifier_response(%{"sources" => [src | _]}) do
    {:ok, src}
  end

  def process_verifier_response(%{"sources" => []}) do
    {:ok, nil}
  end

  def bytecode_search_sources_url, do: "#{base_api_url()}" <> "/bytecodes/sources:search"

  use Explorer.SmartContract.RustVerifierInterfaceBehaviour
end
