import { refreshPage } from '../../lib/async_listing_load'
import { openErrorModal, openSuccessModal } from '../../lib/modals'

export async function makeContractCall (call, store) {
  let gas, timeout
  let resultShown = false
  const account = store.getState().account

  try {
    gas = await call.estimateGas({
      from: account,
      gasPrice: 1000000000
    })
  } catch (err) {
    openErrorModal('Error', 'Your transaction cannot be mined at the moment. Please, try again in a few blocks.')
    return
  }

  try {
    await call.send({
      from: account,
      gas: Math.ceil(gas * 1.2),
      gasPrice: 1000000000
    }).once('transactionHash', (hash) => {
      timeout = setTimeout(() => {
        if (!resultShown) {
          openErrorModal('Error', 'Your transaction cannot be mined at the moment. Please, try again with the increased gas price or fixed nonce (use Reset Account feature of MetaMask).')
          resultShown = true
        }
      }, 30000)
    })

    clearTimeout(timeout)
    refreshPage(store)

    if (!resultShown) {
      openSuccessModal('Success', 'Transaction is confirmed.')
      resultShown = true
    }
  } catch (err) {
    console.log(err)
    clearTimeout(timeout)
    openErrorModal('Error', err.message)
  }
}

