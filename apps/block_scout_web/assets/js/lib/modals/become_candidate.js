import $ from 'jquery'
import * as modals from './utils.js'

window.openBecomeCandidateModal = function () {
  let el = '#becomeCandidateModal'
  if ($(el).length) {
    $(`${el} form`).unbind('submit')
    $(`${el} form`).submit(() => {
      modals.becomeCandidate(el)
      return false
    })
    $(el).modal()
  } else {
    modals.openWarningModal('Unauthorized', 'Please login with MetaMask')
  }
}
