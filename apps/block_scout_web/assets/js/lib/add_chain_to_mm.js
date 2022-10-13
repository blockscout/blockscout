import 'bootstrap'

export async function addChainToMM ({ btn }) {
  try {
    const chainID = await window.ethereum.request({ method: 'eth_chainId' })
    const chainIDFromEnvVar = parseInt(document.body.dataset.chainId)
    const chainIDHex = chainIDFromEnvVar && `0x${chainIDFromEnvVar.toString(16)}`
    const blockscoutURL = location.protocol + '//' + location.host + document.body.dataset.networkPath
    if (chainID !== chainIDHex) {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: chainIDHex,
          chainName: document.body.dataset.subnetwork,
          nativeCurrency: {
            name: document.body.dataset.coinName,
            symbol: document.body.dataset.coinName,
            decimals: 18
          },
          rpcUrls: [document.body.dataset.jsonRpc],
          blockExplorerUrls: [blockscoutURL]
        }]
      })
    } else {
      btn.tooltip('dispose')
      btn.tooltip({
        title: `You're already connected to ${document.body.dataset.subnetwork}`,
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
