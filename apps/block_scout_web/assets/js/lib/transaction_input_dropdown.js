import $ from 'jquery'

$('.tx-input-dropdown').click(function (e) {
  var el = $(e.currentTarget)
  var target = $(el.attr('data-target'))

  target.show()
  target.siblings('.transaction-input').hide()
  $('#tx-input-decoding-button').text(el.text())
})
