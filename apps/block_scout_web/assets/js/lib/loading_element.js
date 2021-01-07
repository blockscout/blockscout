import $ from 'jquery'

$('button[data-loading="animation"]').on("click", () => {
  $('#loading').removeClass('d-none')
})
