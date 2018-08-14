import $ from 'jquery'

$('button[data-loading="animation"]').click(event => {
  const clickedButton = $(event.target)

  clickedButton.addClass('d-none')
  $('#loading').removeClass('d-none')
})
