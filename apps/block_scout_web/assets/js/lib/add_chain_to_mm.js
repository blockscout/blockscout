import 'bootstrap'

export async function addChainToMM ({ btn }) {
  try {
    const chainID = await window.ethereum.request({ method: 'eth_chainId' })
    const chainIDFromEnvVar = parseInt(process.env.CHAIN_ID)
    const chainIDHex = chainIDFromEnvVar && `0x${chainIDFromEnvVar.toString(16)}`
    const blockscoutURL = location.protocol + '//' + location.host + process.env.NETWORK_PATH
    if (chainID !== chainIDHex) {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: chainIDHex,
          chainName: process.env.SUBNETWORK,
          nativeCurrency: {
            name: process.env.COIN_NAME,
            symbol: process.env.COIN_NAME,
            decimals: 18
          },
          rpcUrls: [process.env.JSON_RPC],
          blockExplorerUrls: [blockscoutURL]
        }]
      })
    } else {
      btn.tooltip('dispose')
      btn.tooltip({
        title: `You're already connected to ${process.env.SUBNETWORK}`,
        trigger: 'click',
        placement: 'bottom'
      }).tooltip('show')

      setTimeout(() => {
        btn.tooltip('dispose')
      }, 3000)
    }
  } catch (error) {
    console.error(error)
  }
}
