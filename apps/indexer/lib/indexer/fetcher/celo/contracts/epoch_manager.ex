defmodule Indexer.Fetcher.Celo.Contracts.EpochManager do
  use Ethers.Contract,
    abi_file: "lib/indexer/fetcher/celo/contracts/epoch_manager.json"
end
