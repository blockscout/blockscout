import $ from 'jquery'
import {store} from '../pages/stakes.js'

window.openBecomeCandidateModal = function () {
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
}

window.openRemovePoolModal = function () {
  const modal = '#questionStatusModal'
  $(`${modal} .modal-status-title`).text('Remove my Pool')
  $(`${modal} .modal-status-text`).text('Do you really want to remove your pool?')
  $(`${modal} .btn-line.accept`).unbind('click')
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
    openErrorModal('Error', `You cannot stake less than ${min} POA20`)
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
      const blockContract = new web3.eth.Contract(
        [{
          'constant': true,
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
        const epochEndSec = $('[data-page="stakes"]').data('epoch-end-sec')
        const hours = Math.trunc(epochEndSec / 3600)
        const minutes = Math.trunc((epochEndSec % 3600) / 60)

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

  const contract = store.getState().stakingContract
  const account = store.getState().account

  const unlockModal = function () {
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
