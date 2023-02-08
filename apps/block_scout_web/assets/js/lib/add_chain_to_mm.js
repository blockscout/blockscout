import 'bootstrap'

export async function addChainToMM ({ btn }) {
  try {
    // @ts-ignore
    const chainIDFromWallet = await window.ethereum.request({ method: 'eth_chainId' })
    const chainIDFromInstance = getChainIdHex()

    const coinNameObj = document.getElementById('js-coin-name')
    // @ts-ignore
    const coinName = coinNameObj && coinNameObj.value
    const subNetworkObj = document.getElementById('js-subnetwork')
    // @ts-ignore
    const subNetwork = subNetworkObj && subNetworkObj.value
    const jsonRPCObj = document.getElementById('js-json-rpc')
    // @ts-ignore
    const jsonRPC = jsonRPCObj && jsonRPCObj.value
    // @ts-ignore
    const path = process.env.NETWORK_PATH || '/'

    const blockscoutURL = location.protocol + '//' + location.host + path
    if (chainIDFromWallet !== chainIDFromInstance) {
      // @ts-ignore
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: chainIDFromInstance,
          chainName: subNetwork,
          nativeCurrency: {
            name: coinName,
            symbol: coinName,
            decimals: 18
          },
          rpcUrls: [jsonRPC],
          blockExplorerUrls: [blockscoutURL]
        }]
      })
    } else {
      btn.tooltip('dispose')
      btn.tooltip({
        title: `You're already connected to ${subNetwork}`,
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

function getChainIdHex () {
  const chainIDObj = document.getElementById('js-chain-id')
  // @ts-ignore
  const chainIDFromDOM = chainIDObj && chainIDObj.value
  const chainIDFromInstance = parseInt(chainIDFromDOM)
  return chainIDFromInstance && `0x${chainIDFromInstance.toString(16)}`
}
