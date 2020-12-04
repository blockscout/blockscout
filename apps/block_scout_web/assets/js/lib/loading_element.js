import $ from 'jquery'

$('button[data-loading="animation"]').click(_event => {
  $('#loading').removeClass('d-none')
})
