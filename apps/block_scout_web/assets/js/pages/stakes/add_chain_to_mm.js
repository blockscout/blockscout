import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('click', '.btn-add-chain-to-mm', event => {
    const $btn = $(event.target)
    addChainToMM({ btn: $btn })
  })

async function addChainToMM ({ btn }) {
  try {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' })
    if (chainId !== '0x64') {
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: '0x64',
          chainName: 'xDai Chain',
          nativeCurrency: {
            name: 'xDAI',
            symbol: 'xDAI',
            decimals: 18
          },
          rpcUrls: ['https://dai.poa.network'],
          iconUrls: ['https://gblobscdn.gitbook.com/assets%2F-Lpi9AHj62wscNlQjI-l%2F-LsI4cyo_805A73-h--i%2F-LsI8IfCk8qZrHalGx_E%2Fxdai_alternative.png'],
          blockExplorerUrls: ['https://blockscout.com/xdai/mainnet']
        }]
      })
    } else {
      btn.tooltip('dispose')
      btn.tooltip({
        title: 'You\'re already connected to xDai chain',
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
