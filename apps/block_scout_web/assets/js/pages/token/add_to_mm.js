import $ from 'jquery'
import 'bootstrap'

$(document.body)
  .on('click', '.btn-add-to-mm', event => {
    const $btn = $(event.target)
    const tokenAddress = $btn.data('token-address')
    const tokenSymbol = $btn.data('token-symbol')
    const tokenDecimals = $btn.data('token-decimals')

    addTokenToMM({ tokenAddress, tokenSymbol, tokenDecimals, tokenImage: null, btn: $btn })
  })
$(document.body)
  .on('mouseover', '.btn-add-to-mm', event => {
    const $btn = $(event.target)
    const tokenSymbol = $btn.data('token-symbol')

    $btn.tooltip('dispose')
    $btn.tooltip({
      title: `Add ${tokenSymbol} to MetaMask`,
      trigger: 'hover',
      placement: 'top'
    }).tooltip('show')
  })

async function addTokenToMM ({ tokenAddress, tokenSymbol, tokenDecimals, tokenImage, btn }) {
  try {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' })
    if (chainId === '0x64') {
      await window.ethereum.request({
        method: 'wallet_watchAsset',
        params: {
          type: 'ERC20', // Initially only supports ERC20, but eventually more!
          options: {
            address: tokenAddress, // The address that the token is at.
            symbol: tokenSymbol, // A ticker symbol or shorthand, up to 5 chars.
            decimals: tokenDecimals, // The number of decimals in the token
            image: tokenImage // A string url of the token logo
          }
        }
      })
    } else {
      btn.tooltip('dispose')
      btn.tooltip({
        title: 'You\'re not connected to xDai chain',
        trigger: 'click',
        placement: 'top'
      }).tooltip('show')

      setTimeout(() => {
        btn.tooltip('dispose')
      }, 3000)
    }
  } catch (error) {
    console.error(error)
  }
}
