import $ from 'jquery'
import humps from 'humps'
import moment from 'moment'
import Chart from 'chart.js'
import {store} from '../pages/stakes.js'

window.openBecomeCandidateModal = function () {
  let el = '#becomeCandidateModal'
  if ($(el).length) {
    $(`${el} form`).unbind('submit')
    $(`${el} form`).submit(() => {
      becomeCandidate(el)
      return false
    })
    $(el).modal()
  } else {
    openWarningModal('Unauthorized', 'Please login with MetaMask')
  }
}

window.openRemovePoolModal = function () {
  let modal = '#questionStatusModal'
  openQuestionModal('Remove my Pool', 'Do you really want to remove your pool?')
  $(`${modal} .btn-line.accept`).click(() => {
    removeMyPool(modal)
    return false
  })

  $(`${modal} .btn-line.except`).unbind('click')
  $(`${modal} .btn-line.except`).click(() => {
    $(modal).modal('hide')
  })
  $(modal).modal()
}

window.openMakeStakeModal = async function (poolAddress) {
  let modal = '#stakeModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    setProgressInfo(modal, pool)

    $(`${modal} form`).unbind('submit')
    $(`${modal} form`).on('submit', (e) => makeStake(e, modal, poolAddress))

    $(modal).modal('show')
  } catch (_) {
    $(modal).modal('hide')
    openErrorModal('Error', 'Something went wrong')
  }
}

window.openMoveStakeModal = async function (poolAddress) {
  let modal = '#moveStakeModal'

  try {
    let responseforPool = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(responseforPool.pool)
    let relation = humps.camelizeKeys(responseforPool.relation)
    let response = await $.getJSON('/staking_pools')
    let pools = []

    $.each(response.pools, (_key, pool) => {
      let p = humps.camelizeKeys(pool)
      if (p.stakingAddressHash !== poolAddress) {
        pools.push(p)
      }
    })

    setProgressInfo(modal, pool)
    let tokenSymbol = store.getState().tokenSymbol
    $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)
    $(`${modal} [max-allowed]`).text(`${relation.maxWithdrawAllowed} ${tokenSymbol}`)

    $.each($(`${modal} [pool-select] option:not(:first-child)`), (_, opt) => {
      opt.remove()
    })

    $.each(pools, (_key, pool) => {
      var $option = $('<option/>', {
        value: pool.stakingAddressHash,
        text: pool.stakingAddressHash.slice(0, 13)
      })
      $(`${modal} [pool-select]`).append($option)
    })

    $(`${modal} [pool-select]`).on('change', e => {
      let selectedAddress = e.currentTarget.value
      let amount = $(`${modal} [move-amount]`).val()
      window.openMoveStakeSelectedModal(poolAddress, selectedAddress, amount, pools)
      $(modal).modal('hide')
    })

    $(modal).modal('show')
  } catch (err) {
    console.log(err)
    $(modal).modal('hide')
    openErrorModal('Error', 'Something went wrong')
  }
}

window.openMoveStakeSelectedModal = async function (fromAddress, toAddress, amount = null, pools = []) {
  let modal = '#moveStakeModalSelected'
  let response = await $.getJSON('/staking_pool', { 'pool_hash': fromAddress })
  let fromPool = humps.camelizeKeys(response.pool)
  let relation = humps.camelizeKeys(response.relation)
  let tokenSymbol = store.getState().tokenSymbol

  setProgressInfo(modal, fromPool, '.js-pool-from-progress')

  $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)
  $(`${modal} [max-allowed]`).text(`${relation.maxWithdrawAllowed} ${tokenSymbol}`)
  $(`${modal} [move-amount]`).val(amount)

  response = await $.getJSON('/staking_pool', { 'pool_hash': toAddress })
  let toPool = humps.camelizeKeys(response.pool)

  setProgressInfo(modal, toPool, '.js-pool-to-progress')

  $.each(pools, (_key, pool) => {
    var $option = $('<option/>', {
      value: pool.stakingAddressHash,
      text: pool.stakingAddressHash.slice(0, 13),
      selected: pool.stakingAddressHash === toAddress
    })

    $(`${modal} [pool-select]`).append($option)
  })

  $(`${modal} [pool-select]`).unbind('change')

  $(`${modal} [pool-select]`).on('change', e => {
    let selectedAddress = e.currentTarget.value
    let amount = $(`${modal} [move-amount]`).val()
    window.openMoveStakeSelectedModal(fromAddress, selectedAddress, amount)
  })

  $(`${modal} form`).unbind('submit')
  $(`${modal} form`).on('submit', e => moveStake(e, modal, fromAddress, toAddress))

  $(modal).modal('show')
}

window.openClaimQuestionModal = function (poolAddress) {
  let modal = '#questionStatusModal'

  openQuestionModal('Claim or order', 'Do you want withdraw or claim ordered withdraw?', 'Claim', 'Withdraw')

  $(`${modal} .btn-line.accept`).click(() => {
    window.openClaimModal(poolAddress)
    $(modal).modal('hide')
    return false
  })

  $(`${modal} .btn-line.except`).click(() => {
    window.openWithdrawModal(poolAddress)
    $(modal).modal('hide')
    return false
  })
}

window.openClaimModal = async function (poolAddress) {
  let modal = '#claimModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    let relation = humps.camelizeKeys(response.relation)
    let tokenSymbol = store.getState().tokenSymbol

    setProgressInfo(modal, pool)

    $(`${modal} [ordered-amount]`).text(`${relation.orderedWithdraw} ${tokenSymbol}`)
    $(`${modal} form`).unbind('submit')
    $(`${modal} form`).on('submit', _ => claimWithdraw(modal, poolAddress))

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    openErrorModal('Error', 'Something went wrong')
  }
}

window.openWithdrawModal = async function (poolAddress) {
  let modal = '#withdrawModal'

  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    setProgressInfo(modal, pool)
    let relation = humps.camelizeKeys(response.relation)

    let tokenSymbol = store.getState().tokenSymbol
    $(`${modal} [user-staked]`).text(`${relation.stakeAmount} ${tokenSymbol}`)

    let $withdraw = $(`${modal} .btn-full-primary.withdraw`)
    let $order = $(`${modal} .btn-full-primary.order_withdraw`)

    $withdraw.attr('disabled', true)
    $order.attr('disabled', true)
    if (relation.maxWithdrawAllowed > 0) {
      $withdraw.attr('disabled', false)
    }
    if (relation.maxOrderedWithdrawAllowed > 0) {
      $order.attr('disabled', false)
    }

    $withdraw.unbind('click')
    $withdraw.on('click', e => withdrawOrOrderStake(e, modal, poolAddress, 'withdraw'))

    $order.unbind('click')
    $order.on('click', e => withdrawOrOrderStake(e, modal, poolAddress, 'order'))

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    openErrorModal('Error', 'Something went wrong')
  }
}

window.openPoolInfoModal = async function (poolAddress) {
  let modal = '#poolInfoModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)

    $(`${modal} [staking-address]`).text(pool.stakingAddressHash)
    $(`${modal} [mining-address]`).text(pool.miningAddressHash)
    $(`${modal} [self-staked]`).text(pool.selfStakedAmount)
    $(`${modal} [delegators-staked]`).text(pool.stakedAmount)
    $(`${modal} [stakes-ratio]`).text(`${pool.stakedRatio || 0.00} %`)
    $(`${modal} [reward-percent]`).text(`${pool.blockReward || 0.00} %`)
    $(`${modal} [was-validator]`).text(pool.wasValidatorCount)
    $(`${modal} [was-banned]`).text(pool.wasBannedCount)

    if (pool.isBanned) {
      let currentBlock = store.getState().blocksCount
      let blocksLen = pool.bannedUntil - currentBlock
      let blockTime = $('[data-page="stakes"]').data('average-block-time')
      let banDuring = blockTime * blocksLen
      var dt = moment().add(banDuring, 'seconds').format('D MMM Y')

      $(`${modal} [unban-date]`).text(`Banned until block #${pool.bannedUntil} (${dt})`)
    } else {
      $(`${modal} [unban-date]`).text('-')
    }
    $(`${modal} [likelihood]`).text(`${pool.likelihood || 0.00} %`)
    $(`${modal} [delegators-count]`).text(pool.delegatorsCount)

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    openErrorModal('Error', 'Something went wrong')
  }
}

function setProgressInfo (modal, pool, elClass = '') {
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

function lockModal (el) {
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

function unlockAndHideModal (el) {
  var $submitButton = $(`${el} .btn-add-full`)

  $(el).unbind()
  $(el).modal('hide')
  $(`${el} .close-modal`).attr('disabled', false)

  $submitButton.attr('disabled', false)
}

function openErrorModal (title, text) {
  $(`#errorStatusModal .modal-status-title`).text(title)
  $(`#errorStatusModal .modal-status-text`).text(text)
  $('#errorStatusModal').modal('show')
}

function openSuccessModal (title, text) {
  $(`#successStatusModal .modal-status-title`).text(title)
  $(`#successStatusModal .modal-status-text`).text(text)
  $('#successStatusModal').modal('show')
}

function openWarningModal (title, text) {
  let modal = '#warningStatusModal'
  $(`${modal} .modal-status-title`).text(title)
  $(`${modal} .modal-status-text`).text(text)
  $(modal).modal('show')
}

function openQuestionModal (title, text, accept_text = 'Yes', except_text = 'No') {
  let modal = '#questionStatusModal'

  $(`${modal} .modal-status-title`).text(title)
  $(`${modal} .modal-status-text`).text(text)

  $(`${modal} .btn-line.accept .btn-line-text`).text(accept_text)
  $(`${modal} .btn-line.accept`).unbind('click')

  $(`${modal} .btn-line.except .btn-line-text`).text(except_text)
  $(`${modal} .btn-line.except`).unbind('click')

  $(modal).modal()
}

async function becomeCandidate (el) {
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
      contract.methods.addPool(stake * Math.pow(10, 18), address).send({
        from: account,
        gas: 400000,
        gasPrice: 1000000000
      })
        .on('receipt', _receipt => {
          unlockAndHideModal(el)
          $submitButton.html(buttonText)
          store.dispatch({ type: 'START_REQUEST' })
          store.dispatch({ type: 'GET_USER' })
          store.dispatch({ type: 'RELOAD_POOLS_LIST' })
          openSuccessModal('Success', 'The transaction is created')
        })
        .catch(_err => {
          unlockAndHideModal(el)
          $submitButton.html(buttonText)
          openErrorModal('Error', 'Something went wrong')
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

async function removeMyPool (el) {
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

  contract.methods.removeMyPool().send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockModal()
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockModal()
      openErrorModal('Error', 'Something went wrong')
    })
}

function makeStake (event, modal, poolAddress) {
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

  contract.methods.stake(poolAddress, amount * Math.pow(10, 18)).send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      openErrorModal('Error', 'Something went wrong')
    })

  return false
}

function moveStake (e, modal, fromAddress, toAddress) {
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

  contract.methods.moveStake(fromAddress, toAddress, amount * Math.pow(10, 18)).send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      openErrorModal('Error', 'Something went wrong')
    })

  return false
}

function withdrawOrOrderStake (e, modal, poolAddress, method) {
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

  contractMethod.send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockAndHideModal(modal)
      $withdraw.html(withdrawText)
      $order.html(orderText)
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockAndHideModal(modal)
      $withdraw.html(withdrawText)
      $order.html(orderText)
      openErrorModal('Error', 'Something went wrong')
    })
}

function claimWithdraw (modal, poolAddress) {
  let contract = store.getState().stakingContract
  let account = store.getState().account
  var $submitButton = $(`${modal} .btn-add-full`)
  let buttonText = $submitButton.html()
  lockModal(modal)

  contract.methods.claimOrderedWithdraw(poolAddress).send({
    from: account,
    gas: 400000,
    gasPrice: 1000000000
  })
    .on('receipt', _receipt => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      store.dispatch({ type: 'START_REQUEST' })
      store.dispatch({ type: 'GET_USER' })
      store.dispatch({ type: 'RELOAD_POOLS_LIST' })
      openSuccessModal('Success', 'The transaction is created')
    })
    .catch(_err => {
      unlockAndHideModal(modal)
      $submitButton.html(buttonText)
      openErrorModal('Error', 'Something went wrong')
    })

  return false
}

function setupStakesProgress (progress, total, stakeProgress) {
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