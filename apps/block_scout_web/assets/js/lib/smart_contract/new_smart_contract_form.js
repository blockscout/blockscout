import $ from 'jquery'

$(function () {
  $('.js-btn-add-contract-libraries').on('click', function () {
    $('.js-smart-contract-libraries-wrapper').show()
    $(this).remove()
  })
})
