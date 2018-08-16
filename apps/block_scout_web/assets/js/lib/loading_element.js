import $ from 'jquery'

$('button[data-loading="animation"]').click(event => {
  $('#loading').removeClass('d-none')
})
