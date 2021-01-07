import $ from 'jquery'

$('.tx-input-dropdown').on("click", function (e) {
  e.preventDefault()

  var el = $(e.currentTarget)
  var target = $(el.attr('data-target'))

  target.show()
  target.siblings('.transaction-input').hide()
  $('#tx-input-decoding-button').text(el.text())
})
