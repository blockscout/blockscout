import { refreshPage } from '../../lib/async_listing_load'
import { openErrorModal, openSuccessModal } from '../../lib/modals'

export async function makeContractCall (call, store) {
  let timeout

  try {
    const account = store.getState().account
    const gas = await call.estimateGas({
      from: account,
      gasPrice: 1000000000
    })

    await call.send({
      from: account,
      gas: Math.ceil(gas * 1.2),
      gasPrice: 1000000000
    }).once('transactionHash', (hash) => {
      timeout = setTimeout(() => {
        openErrorModal('Error', 'Your transaction cannot be mined at the moment. Please, try again with the increased gas price or fixed nonce (use Reset Account feature of MetaMask).')
      }, 15000)
    })

    clearTimeout(timeout)
    refreshPage(store)
    openSuccessModal('Success', 'Transaction is confirmed.')
  } catch (err) {
    console.log(err)
    clearTimeout(timeout)
    openErrorModal('Error', err.message)
  }
}

