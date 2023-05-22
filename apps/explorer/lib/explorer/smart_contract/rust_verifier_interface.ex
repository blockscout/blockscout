defmodule Explorer.SmartContract.RustVerifierInterface do
  @moduledoc """
    Adapter for contracts verification with https://github.com/blockscout/blockscout-rs/blob/main/smart-contract-verifier
  """
  use Explorer.SmartContract.RustVerifierInterfaceBehaviour
end
