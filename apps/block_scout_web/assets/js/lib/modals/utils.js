import $ from 'jquery'
import Chart from 'chart.js'
import {store} from '../pages/stakes.js'

export function setProgressInfo (modal, pool, elClass = '') {
  let selfAmount = parseFloat(pool.selfStakedAmount)
  let amount = parseFloat(pool.stakedAmount)
  let ratio = parseFloat(pool.stakedRatio)

  $(`${modal} [stakes-progress]${elClass}`).text(selfAmount)
  $(`${modal} [stakes-total]${elClass}`).text(amount)
  $(`${modal} [stakes-address]${elClass}`).text(pool.stakingAddressHash.slice(0, 13))
  $(`${modal} [stakes-address]${elClass}`).on('click', _ => window.openPoolInfoModal(pool.stakingAddressHash))
  $(`${modal} [stakes-ratio]${elClass}`).text(`${ratio || 0} %`)
  $(`${modal} [stakes-delegators]${elClass}`).text(pool.delegatorsCount)

  setupStakesProgress(selfAmount, amount, $(`${modal} .js-stakes-progress${elClass}`))
}

export function lockModal (el) {
  var $submitButton = $(`${el} .btn-add-full`)

  $(`${el} .close-modal`).attr('disabled', true)
  $(el).on('hide.bs.modal', e => {
    e.preventDefault()
    e.stopPropagation()
  })

  $submitButton.attr('disabled', true)
  $submitButton.html(`
    <span class="loading-spinner-small mr-2">
      <span class="loading-spinner-block-1"></span>
      <span class="loading-spinner-block-2"></span>
    </span>`)
}

export function unlockAndHideModal (el) {
  var $submitButton = $(`${el} .btn-add-full`)

  $(el).unbind()
  $(el).modal('hide')
  $(`${el} .close-modal`).attr('disabled', false)

  $submitButton.attr('disabled', false)
}

export function openErrorModal (title, text) {
  $(`#errorStatusModal .modal-status-title`).text(title)
  $(`#errorStatusModal .modal-status-text`).text(text)
  $('#errorStatusModal').modal('show')
}

export function openSuccessModal (title, text) {
  $(`#successStatusModal .modal-status-title`).text(title)
  $(`#successStatusModal .modal-status-text`).text(text)
  $('#successStatusModal').modal('show')
}

export function openWarningModal (title, text) {
  let modal = '#warningStatusModal'
  $(`${modal} .modal-status-title`).text(title)
  $(`${modal} .modal-status-text`).text(text)
  $(modal).modal('show')
}

export function openQuestionModal (title, text, accept_text = 'Yes', except_text = 'No') {
  let modal = '#questionStatusModal'

  $(`${modal} .modal-status-title`).text(title)
  $(`${modal} .modal-status-text`).text(text)

  $(`${modal} .btn-line.accept .btn-line-text`).text(accept_text)
  $(`${modal} .btn-line.accept`).unbind('click')

  $(`${modal} .btn-line.except .btn-line-text`).text(except_text)
  $(`${modal} .btn-line.except`).unbind('click')

  $(modal).modal()
}

export async function becomeCandidate (el) {
  lockModal(el)
  let web3 = store.getState().web3
  let $submitButton = $(`${el} .btn-add-full`)
  let buttonText = $submitButton.html()
  let stake = parseFloat($(`${el} [candidate-stake]`).val())
  let address = $(`${el} [mining-address]`).val()
  let contract = store.getState().stakingContract
  let account = store.getState().account

  if (!stake || stake < $(el).data('min-stake')) {
    var min = $(el).data('min-stake')
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    let tokenSymbol = store.getState().tokenSymbol
    openErrorModal('Error', `You cannot stake less than ${min} ${tokenSymbol}`)
    return false
  }

  if (account === address || !web3.utils.isAddress(address)) {
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    openErrorModal('Error', 'Invalid Mining Address')
    return false
  }

  try {
    var stakeAllowed = await contract.methods.areStakeAndWithdrawAllowed().call()
    if (!stakeAllowed) {
      unlockAndHideModal(el)
      $submitButton.html(buttonText)
      let blockContract = new web3.eth.Contract(
        [{
          'letant': true,
          'inputs': [],
          'name': 'isSnapshotting',
          'outputs': [
            {
              'name': '',
              'type': 'bool'
            }
          ],
          'payable': false,
          'stateMutability': 'view',
          'type': 'function'
        }],
        '0x2000000000000000000000000000000000000001'
      )
      var isSnapshotting = await blockContract.methods.isSnapshotting().call()
      if (isSnapshotting) {
        openErrorModal('Error', 'Stakes are not allowed at the moment. Please try again in a few blocks')
      } else {
        let epochEndSec = $('[data-page="stakes"]').data('epoch-end-sec')
        let hours = Math.trunc(epochEndSec / 3600)
        let minutes = Math.trunc((epochEndSec % 3600) / 60)

        openErrorModal('Error', `Since the current staking epoch is finishing now, you will be able to place a stake during the next staking epoch. Please try again in ${hours} hours ${minutes} minutes`)
      }
    } else {
      let contractMethod = contract.methods.addPool(stake * Math.pow(10, 18), address)

      invoke(el, account, contractMethod, () => {
        $submitButton.html(buttonText)
      })
    }
  } catch (err) {
    console.log(err)
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    openErrorModal('Error', 'Something went wrong')
  }

  return false
}

export async function removeMyPool (el) {
  $(`${el} .close-modal`).attr('disabled', true)
  $(el).on('hide.bs.modal', e => {
    e.preventDefault()
    e.stopPropagation()
  })
  $(el).find('.btn-line').attr('disabled', true)

  let contract = store.getState().stakingContract
  let account = store.getState().account

  let unlockModal = function () {
    $(el).unbind()
    $(el).modal('hide')
    $(`${el} .close-modal`).attr('disabled', false)
    $(el).find('.btn-line').attr('disabled', false)
  }

  let contractMethod = contract.methods.removeMyPool()

  invoke(el, account, contractMethod, () => {
    unlockModal()
  })
}

export function makeStake (event, modal, poolAddress) {
  let amount = parseFloat(event.target[0].value)
  let minStake = parseFloat($(modal).data('min-stake'))
  let tokenSymbol = store.getState().tokenSymbol

  if (amount < minStake) {
    $(modal).modal('hide')
    openErrorModal('Error', `You cannot stake less than ${minStake} ${tokenSymbol}`)
    return false
  }

  let contract = store.getState().stakingContract
  let account = store.getState().account
  let $submitButton = $(`${modal} .btn-add-full`)
  let buttonText = $submitButton.html()
  lockModal(modal)

  let contractMethod = contract.methods.stake(poolAddress, amount * Math.pow(10, 18))

  invoke(modal, account, contractMethod, () => {
    $submitButton.html(buttonText)
  })

  return false
}

export function moveStake (e, modal, fromAddress, toAddress) {
  let amount = parseFloat(e.target[0].value)
  let allowed = parseFloat($(`${modal} [max-allowed]`).text())
  let minStake = parseInt($(modal).data('min-stake'))
  let tokenSymbol = store.getState().tokenSymbol

  if (amount < minStake || amount > allowed) {
    $(modal).modal('hide')
    openErrorModal('Error', `You cannot stake less than ${minStake} ${tokenSymbol} and more than ${allowed} ${tokenSymbol}`)
    return false
  }

  let contract = store.getState().stakingContract
  let account = store.getState().account
  let $submitButton = $(`${modal} .btn-add-full`)
  let buttonText = $submitButton.html()
  lockModal(modal)

  let contractMethod = contract.methods.moveStake(fromAddress, toAddress, amount * Math.pow(10, 18))

  invoke(modal, account, contractMethod, () => {
    $submitButton.html(buttonText)
  })

  return false
}

export function withdrawOrOrderStake (e, modal, poolAddress, method) {
  e.preventDefault()
  e.stopPropagation()
  let amount = parseFloat($(`${modal} [amount]`).val())

  let contract = store.getState().stakingContract
  let account = store.getState().account
  let $withdraw = $(`${modal} .btn-full-primary.withdraw`)
  let withdrawText = $withdraw.text()
  let $order = $(`${modal} .btn-full-primary.order_withdraw`)
  let orderText = $order.text()

  lockModal(modal)

  let weiVal = amount * Math.pow(10, 18)

  var contractMethod

  if (method === 'withdraw') {
    contractMethod = contract.methods.withdraw(poolAddress, weiVal)
  } else {
    contractMethod = contract.methods.orderWithdraw(poolAddress, weiVal)
  }

  invoke(modal, account, contractMethod, () => {
    $withdraw.html(withdrawText)
    $order.html(orderText)
  })
}

export function invoke (modal, account, method, andFinally = (() => {})) {
  method.send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockAndHideModal(modal)
      andFinally()
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockAndHideModal(modal)
      andFinally()
      openErrorModal('Error', 'Something went wrong')
    })
}

export function claimWithdraw (modal, poolAddress) {
  let contract = store.getState().stakingContract
  let account = store.getState().account
  var $submitButton = $(`${modal} .btn-add-full`)
  let buttonText = $submitButton.html()
  lockModal(modal)

  let contractMethod = contract.methods.claimOrderedWithdraw(poolAddress)

  invoke(account, contractMethod, () => {
    $submitButton.html(buttonText)
  })
  return false
}

export function setupStakesProgress (progress, total, stakeProgress) {
  let primaryColor = $('.btn-full-primary').css('background-color')
  let backgroundColors = [
    primaryColor,
    'rgba(202, 199, 226, 0.5)'
  ]
  let progressBackground = total - progress
  var data
  if (total > 0) {
    data = [progress, progressBackground]
  } else {
    data = [0, 1]
  }

  // eslint-disable-next-line no-unused-vars
  let myChart = new Chart(stakeProgress, {
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
