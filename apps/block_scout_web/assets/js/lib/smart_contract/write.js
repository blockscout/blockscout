import { connectToWallet, disconnectWallet, init } from './connect.js'

window.addEventListener('load', async () => {
  init()
  document.querySelector('[connect-wallet]') && document.querySelector('[connect-wallet]').addEventListener('click', connectToWallet)
  document.querySelector('[disconnect-wallet]') && document.querySelector('[disconnect-wallet]').addEventListener('click', disconnectWallet)
})
