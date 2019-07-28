import $ from 'jquery'
import Chart from 'chart.js'
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

export function setupChart ($canvas, self, total) {
  const primaryColor = $('.btn-full-primary').css('background-color')
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
