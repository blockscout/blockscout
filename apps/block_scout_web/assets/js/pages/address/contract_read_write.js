import $ from 'jquery'

const classSelected = 'btn-line-inversed'
const classNotSelected = 'btn-line'

if ($('[class="functions-tabs"]').length) {
  $('[data-smart-contract-functions]').show()
  $('[data-smart-contract-functions-custom]').hide()

  $('#tab-verified').on('click', function () {
    if ($(this).prop('checked')) {
      $('[label-verified]').addClass(classSelected)
      $('[label-verified]').removeClass(classNotSelected)
      $('[label-custom]').addClass(classNotSelected)
      $('[label-custom]').removeClass(classSelected)
      $('[data-smart-contract-functions]').show()
      $('[data-smart-contract-functions-custom]').hide()
    }
  })

  $('#tab-custom').on('click', function () {    
    if ($(this).prop('checked')) {
      $('[label-verified]').addClass(classNotSelected)
      $('[label-verified]').removeClass(classSelected)
      $('[label-custom]').addClass(classSelected)
      $('[label-custom]').removeClass(classNotSelected)
      $('[data-smart-contract-functions]').hide()
      $('[data-smart-contract-functions-custom]').show()
    }
  })
}