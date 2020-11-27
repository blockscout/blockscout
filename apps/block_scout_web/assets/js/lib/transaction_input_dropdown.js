import $ from 'jquery'

$('.tx-input-dropdown').click(function (e) {
  e.preventDefault()

  const el = $(e.currentTarget)
  const target = $(el.attr('data-target'))

  target.show()
  target.siblings('.transaction-input').hide()
  $('#tx-input-decoding-button').text(el.text())
})
