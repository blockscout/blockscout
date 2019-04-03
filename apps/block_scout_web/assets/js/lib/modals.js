import $ from 'jquery'

$(function () {
  $('.js-become-candidate').on('click', function () {
    $('#becomeCandidateModal').modal()
  })

  $('.js-validator-info-modal').on('click', function () {
    $('#validatorInfoModal').modal()
  })
})
