import $ from 'jquery'
import Chart from 'chart.js'
import { refreshPage } from '../../lib/async_listing_load'
import { openErrorModal, openSuccessModal, openWarningModal } from '../../lib/modals'

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
    clearTimeout(timeout)
    let errorMessage = 'Your MetaMask transaction was not processed, please try again in a few minutes.'
    if (err.message) {
      const detailsMessage = err.message.replace(/["]/g, '&quot;')
      console.log(detailsMessage)
      const detailsHTML = ` <a href data-boundary="window" data-container="body" data-html="false" data-placement="top" data-toggle="tooltip" title="${detailsMessage}" data-original-title="${detailsMessage}">Details</a>`
      errorMessage = errorMessage + detailsHTML
    }
    openErrorModal('Error', errorMessage)
  }
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
    openErrorModal('Actions temporarily disallowed', 'The current staking epoch is ending, and staking actions are temporarily restricted. Please try again after the new epoch starts.')
    return false
  }
  return true
}

export function isSupportedNetwork (store) {
  const state = store.getState()
  if (state.network && state.network.authorized) {
    return true
  }
  openWarningModal('Unauthorized', 'Please, connect to the xDai Chain.<br /><a href="https://xdaichain.com" target="_blank">Instructions</a>')
  return false
}
