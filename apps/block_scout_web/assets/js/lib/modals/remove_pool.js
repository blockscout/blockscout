import $ from 'jquery'
import * as modals from './utils.js'

window.openRemovePoolModal = function () {
  let modal = '#questionStatusModal'
  modals.openQuestionModal('Remove my Pool', 'Do you really want to remove your pool?')
  $(`${modal} .btn-line.accept`).click(() => {
    modals.removeMyPool(modal)
    return false
  })

  $(`${modal} .btn-line.except`).unbind('click')
  $(`${modal} .btn-line.except`).click(() => {
    $(modal).modal('hide')
  })
  $(modal).modal()
}
