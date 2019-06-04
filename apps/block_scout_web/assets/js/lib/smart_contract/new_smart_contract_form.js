import $ from 'jquery'

$(function () {
  $('.js-btn-add-contract-libraries').on('click', function () {
    $('.js-smart-contract-libraries-wrapper').show()
    $(this).hide()
  })

  $('.js-smart-contract-form-reset').on('click', function () {
    $('.js-contract-library-form-group').removeClass('active')
    $('.js-contract-library-form-group').first().addClass('active')
    $('.js-smart-contract-libraries-wrapper').hide()
    $('.js-btn-add-contract-libraries').show()
    $('.js-add-contract-library-wrapper').show()
  })

  $('.js-btn-add-contract-library').on('click', function () {
    let nextContractLibrary = $('.js-contract-library-form-group.active').next('.js-contract-library-form-group')

    if (nextContractLibrary) {
      nextContractLibrary.addClass('active')
    }

    if ($('.js-contract-library-form-group.active').length === $('.js-contract-library-form-group').length) {
      $('.js-add-contract-library-wrapper').hide()
    }
  })
})
