import $ from 'jquery'
import Chart from 'chart.js'
import { openErrorModal, openSuccessModal, openWarningModal } from '../../lib/modals'

export async function makeContractCall (call, store, gasLimit, callbackFunc) {
  const state = store.getState()
  const from = state.account
  const web3 = state.web3

  if (!callbackFunc) {
    callbackFunc = function (errorMessage) {
      if (!errorMessage) {
        openSuccessModal('Success', 'Transaction is confirmed.')
        state.refreshPageFunc(store)
      } else {
        openErrorModal('Error', errorMessage)
      }
    }
  }

  if (!from) {
    return callbackFunc('Your MetaMask account is undefined. Please, ensure you are using the latest version of MetaMask and connected it to the page')
  } else if (!web3) {
    return callbackFunc('Web3 is undefined. Please, contact support.')
  }

  const gasPrice = web3.utils.toWei('1', 'gwei')

  if (!gasLimit) {
    try {
      gasLimit = await call.estimateGas({ from, gasPrice })
    } catch (e) {
      console.log(`from = ${from}`)
      console.error(e)
      return callbackFunc('Your transaction cannot be mined at the moment. Please, try again in a few blocks.')
    }
  }

  call.send({
    from,
    gasPrice,
    gas: Math.ceil(gasLimit * 1.2) // +20% reserve to ensure enough gas
  }, async function (error, txHash) {
    if (error) {
      let errorMessage = 'Your transaction wasn\'t processed, please try again in a few blocks.'
      if (error.message) {
        const detailsMessage = error.message.replace(/["]/g, '&quot;')
        console.log(detailsMessage)
        const detailsHTML = ` <a href="javascript:void(0);" data-boundary="window" data-container="body" data-html="false" data-placement="top" data-toggle="tooltip" title="${detailsMessage}" data-original-title="${detailsMessage}" class="link-helptip">Details</a>`
        errorMessage = errorMessage + detailsHTML
      }
      callbackFunc(errorMessage)
    } else {
      try {
        let tx
        let currentBlockNumber
        const maxWaitBlocks = 6
        const startBlockNumber = (await web3.eth.getBlockNumber()) - 0
        const finishBlockNumber = startBlockNumber + maxWaitBlocks
        do {
          await sleep(5) // seconds
          tx = await web3.eth.getTransactionReceipt(txHash)
          currentBlockNumber = await web3.eth.getBlockNumber()
        } while (tx === null && currentBlockNumber <= finishBlockNumber)
        if (tx) {
          if (tx.status === true || tx.status === '0x1') {
            callbackFunc() // success
          } else {
            callbackFunc('Transaction reverted')
          }
        } else {
          callbackFunc(`Your transaction wasn't processed in ${maxWaitBlocks} blocks. Please, try again with the increased gas price or fixed nonce (use Reset Account feature of MetaMask).`)
        }
      } catch (e) {
        callbackFunc(e.message)
      }
    }
  })
}

export function setupChart ($canvas, self, total) {
  const primaryColor = $('.stakes-progress-graph-thing-for-getting-color').css('color')
  const backgroundColors = [
    primaryColor,
    'rgba(202, 199, 226, 0.5)'
  ]
  const data = total > 0 ? [self, total - self] : [0, 1]

  // eslint-disable-next-line no-new
  new Chart($canvas, {
    type: 'doughnut',
    data: {
      datasets: [{
        data: data,
        backgroundColor: backgroundColors,
        hoverBackgroundColor: backgroundColors,
        borderWidth: 0
      }]
    },
    options: {
      cutoutPercentage: 80,
      legend: {
        display: false
      },
      tooltips: {
        enabled: false
      }
    }
  })
}

export function checkForTokenDefinition (store) {
  if (store.getState().stakingTokenDefined) {
    return true
  }
  openWarningModal('Token unavailable', 'Token contract is not defined yet. Please try later.')
  return false
}

export function isStakingAllowed (state) {
  if (!state.stakingAllowed) {
    openWarningModal('Actions temporarily disallowed', 'The current staking epoch is ending, and staking actions are temporarily restricted. Please try again after the new epoch starts. If the epoch has just started, try again in a few blocks.')
    return false
  }
  return true
}

export function isSupportedNetwork (store) {
  const state = store.getState()
  if (state.network && state.network.authorized) {
    return true
  }
  openWarningModal('Unauthorized', 'Please, connect to the xDai Chain.<br /><a href="https://xdaichain.com" target="_blank">Instructions</a>. If you have already connected to, please update MetaMask to the latest version.')
  return false
}

function sleep (seconds) {
  return new Promise(resolve => setTimeout(resolve, seconds * 1000))
}
