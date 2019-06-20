import $ from 'jquery'
import Chart from 'chart.js'
import {store} from '../pages/stakes.js'

$(function () {
  $('.js-become-candidate').on('click', function () {
    const el = '#becomeCandidateModal'
    if ($(el).length) {
      $(`${el} form`).unbind('submit')
      $(`${el} form`).submit(() => {
        becomeCandidate(el)
        return false
      })
      $(el).modal()
    } else {
      const modal = '#warningStatusModal'
      $(`${modal} .modal-status-title`).text('Unauthorized')
      $(`${modal} .modal-status-text`).text('Please login with MetaMask')
      $(modal).modal()
    }
  })

  $('.js-remove-pool').on('click', function () {
    const modal = '#questionStatusModal'
    $(`${modal} .btn-line.accept`).unbind('click')
    $(`${modal} .btn-line.accept`).click(() => {
      const contract = store.getState().stakingContract
      const account = store.getState().account
      contract.methods.removeMyPool().send({
        from: account,
        gas: 400000,
        gasPrice: 1000000000
      })
    })
    $(`${modal} .btn-line.except`).unbind('click')
    $(`${modal} .btn-line.except`).click(() => {
      $(modal).modal('hide')
    })
    $(modal).modal()
  })
})

window.openValidatorInfoModal = function (id) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')

  $.getJSON(path, {modal_window: 'info', pool_hash: id})
    .done(function (response) {
      el.html(response.window)
      $('#validatorInfoModal').modal()
    })
}

window.openStakeModal = function (id) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')
  $('.modal').modal('hide')
  $('.modal-backdrop').remove()

  $.getJSON(path, {modal_window: 'make_stake', pool_hash: id})
    .done(function (response) {
      el.html(response.window)

      const modal = '#stakeModal'
      const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
      const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

      $(`${modal} form`).unbind('submit')
      $(`${modal} form`).submit(() => {
        const stake = $(`${modal} [name="amount"]`).val()
        const poolAddress = $(`${modal} [name="pool_address"]`).val()
        const contract = store.getState().stakingContract
        const account = store.getState().account
        contract.methods.stake(poolAddress, stake * Math.pow(10, 18)).send({
          from: account,
          gas: 400000,
          gasPrice: 1000000000
        })
        $(modal).modal('hide')
        return false
      })
      $(modal).modal()

      setupStakesProgress(progress, total, $(`${modal} .js-stakes-progress`))
    })
}

window.openWithdrawModal = function (id) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')
  $('.modal').modal('hide')
  $('.modal-backdrop').remove()

  $.getJSON(path, {modal_window: 'withdraw', pool_hash: id})
    .done(function (response) {
      el.html(response.window)

      const modal = '#withdrawModal'
      const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
      const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

      $(`${modal} form`).unbind('submit')
      $(`${modal} form`).submit(() => { return false })

      $(`${modal} .withdraw`).click(() => {
        const stake = $(`${modal} [name="amount"]`).val()
        const poolAddress = $(`${modal} [name="pool_address"]`).val()
        const contract = store.getState().stakingContract
        const account = store.getState().account
        contract.methods.withdraw(poolAddress, stake * Math.pow(10, 18)).send({
          from: account,
          gas: 400000,
          gasPrice: 1000000000
        })
        $(modal).modal('hide')
      })

      $(`${modal} .order_withdraw`).click(() => {
        const stake = $(`${modal} [name="amount"]`).val()
        const poolAddress = $(`${modal} [name="pool_address"]`).val()
        const contract = store.getState().stakingContract
        const account = store.getState().account
        contract.methods.orderWithdraw(poolAddress, stake * Math.pow(10, 18)).send({
          from: account,
          gas: 400000,
          gasPrice: 1000000000
        })
        $(modal).modal('hide')
      })

      $(modal).modal()

      setupStakesProgress(progress, total, $(`${modal} .js-stakes-progress`))
    })
}

window.openQuestionModal = function (id) {
  const modal = '#claimQuestion'
  $(`${modal} .btn-line.accept`).unbind('click')
  $(`${modal} .btn-line.accept`).click(() => window.openWithdrawModal(id))
  $(`${modal} .btn-line.except`).unbind('click')
  $(`${modal} .btn-line.except`).click(() => window.openClaimModal(id))
  $(modal).modal()
}

window.openClaimModal = function (id) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')
  $('.modal').modal('hide')
  $('.modal-backdrop').remove()

  $.getJSON(path, {modal_window: 'claim', pool_hash: id})
    .done(function (response) {
      el.html(response.window)

      const modal = '#claimModal'
      const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
      const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

      $(`${modal} form`).unbind('submit')
      $(`${modal} form`).submit(() => {
        const poolAddress = $(`${modal} [name="pool_address"]`).val()
        const contract = store.getState().stakingContract
        const account = store.getState().account
        contract.methods.claimOrderedWithdraw(poolAddress).send({
          from: account,
          gas: 400000,
          gasPrice: 1000000000
        })
        $(modal).modal('hide')
        return false
      })
      $(modal).modal()

      setupStakesProgress(progress, total, $(`${modal} .js-stakes-progress`))
    })
}

window.openMoveStakeModal = function (id) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')

  $.getJSON(path, {modal_window: 'move_stake', pool_hash: id})
    .done(function (response) {
      el.html(response.window)

      const modal = '#moveStakeModal'
      const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
      const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

      $(modal).modal()

      setupStakesProgress(progress, total, $(`${modal} .js-stakes-progress`))
    })
}

window.selectedStakeMovePool = function (fromHash, toHash) {
  const el = $('#stakesModalWindows')
  const path = el.attr('current_path')
  $('.modal').modal('hide')
  $('.modal-backdrop').remove()

  $.getJSON(path, {modal_window: 'move_selected', pool_hash: fromHash, pool_to: toHash})
    .done(function (response) {
      el.html(response.window)

      const modal = '#moveStakeModalSelected'
      var progressFrom = parseInt($(`${modal} .js-stakes-progress-data-progress.js-pool-from-progress`).text())
      var totalFrom = parseInt($(`${modal} .js-stakes-progress-data-total.js-pool-from-progress`).text())

      var progressTo = parseInt($(`${modal} .js-stakes-progress-data-progress.js-pool-to-progress`).text())
      var totalTo = parseInt($(`${modal} .js-stakes-progress-data-total.js-pool-to-progress`).text())

      $(`${modal} form`).unbind('submit')
      $(`${modal} form`).submit(() => {
        const poolFrom = $(`${modal} [name="pool_from"]`).val()
        const poolTo = $(`${modal} [name="pool_to"]`).val()
        const stake = $(`${modal} [name="amount"]`).val()
        const contract = store.getState().stakingContract
        const account = store.getState().account
        contract.methods.moveStake(poolFrom, poolTo, stake * Math.pow(10, 18)).send({
          from: account,
          gas: 400000,
          gasPrice: 1000000000
        })
        $(modal).modal('hide')
        return false
      })
      $(modal).modal()

      setupStakesProgress(progressFrom, totalFrom, $(`${modal} .js-pool-from-progress`))
      setupStakesProgress(progressTo, totalTo, $(`${modal} .js-pool-to-progress`))
    })
}

function setupStakesProgress (progress, total, progressElement) {
  const stakeProgress = progressElement
  const primaryColor = $('.btn-full-primary').css('background-color')
  const backgroundColors = [
    primaryColor,
    'rgba(202, 199, 226, 0.5)'
  ]
  const progressBackground = total - progress
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


function lockModal (el) {
  var $submitButton = $(`${el} .btn-add-full`)
  $(`${el} .close-modal`).attr('disabled', true)
  $(el).on('hide.bs.modal', e => {
    e.preventDefault();
    e.stopPropagation();
  })
  $submitButton.attr('disabled', true)
  $submitButton.html('<span class="loading-spinner-small mr-2"><span class="loading-spinner-block-1"></span><span class="loading-spinner-block-2"></span></span>')
}

function unlockAndHideModal (el) {
  var $submitButton = $(`${el} .btn-add-full`)
  $(el).unbind()
  $(el).modal('hide')
  $(`${el} .close-modal`).attr('disabled', false)
  $submitButton.attr('disabled', false)
}

async function becomeCandidate (el) {
  const web3 = store.getState().web3
  var $submitButton = $(`${el} .btn-add-full`)
  const buttonText = $submitButton.html()
  lockModal(el)

  const stake = parseFloat($(`${el} [candidate-stake]`).val())
  const address = $(`${el} [mining-address]`).val()
  const contract = store.getState().stakingContract
  const account = store.getState().account

  if (!stake || stake < $(el).data('min-stake')) {
    var min = $(el).data('min-stake')
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    $(`#errorStatusModal .modal-status-title`).text('Error')
    $(`#errorStatusModal .modal-status-text`).text(`You cannot stake less than ${min} POA20`)
    $('#errorStatusModal').modal('show')
    return false
  }

  if (account === address || !web3.utils.isAddress(address)) {
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    $(`#errorStatusModal .modal-status-title`).text('Error')
    $(`#errorStatusModal .modal-status-text`).text('Invalid Mining Address')
    $('#errorStatusModal').modal('show')
    return false
  }

  try {
    var stakeAllowed = await contract.methods.areStakeAndWithdrawAllowed().call()
    if (!stakeAllowed) {
      unlockAndHideModal(el)
      $submitButton.html(buttonText)
      const blockContract = new web3.eth.Contract(
        [{
          "constant": true,
          "inputs": [],
          "name": "isSnapshotting",
          "outputs": [
            {
              "name": "",
              "type": "bool"
            }
          ],
          "payable": false,
          "stateMutability": "view",
          "type": "function"
        }],
        '0x2000000000000000000000000000000000000001'
      )
      var isSnapshotting = await blockContract.methods.isSnapshotting().call()
      if (isSnapshotting) {
        $(`#errorStatusModal .modal-status-title`).text('Error')
        $(`#errorStatusModal .modal-status-text`).text('Stakes are not allowed at the moment. Please try again in a few blocks')
        $('#errorStatusModal').modal('show')
      } else {
        const epochEndSec = $('[data-page="stakes"]').data('epoch-end-sec')
        const hours = Math.trunc(epochEndSec / 3600)
        const minutes = Math.trunc((epochEndSec % 3600) / 60)

        $(`#errorStatusModal .modal-status-title`).text('Error')
        $(`#errorStatusModal .modal-status-text`).text(`Since the current staking epoch is finishing now, you will be able to place a stake during the next staking epoch. Please try again in ${hours} hours ${minutes} minutes`)
        $('#errorStatusModal').modal('show')
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
        $(`#successStatusModal .modal-status-title`).text('Success')
        $(`#successStatusModal .modal-status-text`).text('The transaction is created')
        $('#successStatusModal').modal('show')
      })
      .catch(_err => {
        unlockAndHideModal(el)
        $submitButton.html(buttonText)
        $(`#errorStatusModal .modal-status-title`).text('Error')
        $(`#errorStatusModal .modal-status-text`).text('Something is wrong')
        $('#errorStatusModal').modal('show')
      })
    }
  } catch (err) {
    console.log(err)
    unlockAndHideModal(el)
    $submitButton.html(buttonText)
    $(`#errorStatusModal .modal-status-title`).text('Error')
    $(`#errorStatusModal .modal-status-text`).text('Something is wrong')
    $('#errorStatusModal').modal('show')
  }
  
  return false
}