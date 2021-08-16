import $ from 'jquery'

$('.tx-input-dropdown').click(function (e) {
  e.preventDefault()

  const el = $(e.currentTarget)
  const target = $(el.data('target'))
  const targetToHide = $(el.data('target-to-hide'))

  target.show()
  targetToHide.hide()
  $('#tx-input-decoding-button').text(el.text())
})
