const modal = createAppKit({
  adapters: [wagmiAdapter],
  projectId,
  networks: [mainnet, arbitrum tesnet],
  metadata: metadata,
  features: {
    swaps: false // Optional - true by default
  }
})
