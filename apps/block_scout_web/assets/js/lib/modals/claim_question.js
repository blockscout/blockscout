import $ from 'jquery'
import * as modals from './utils.js'

window.openClaimQuestionModal = function (poolAddress) {
  let modal = '#questionStatusModal'

  modals.openQuestionModal('Claim or order', 'Do you want withdraw or claim ordered withdraw?', 'Claim', 'Withdraw')

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
