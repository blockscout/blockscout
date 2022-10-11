import $ from 'jquery'

$(document.body).on('click', '.epoch-aggregated-tile-reward-count ', event => {
  $('.epoch-aggregated-tile-transactions-list[data-rewards-type="' + $(event.target).data('rewards-type') + '"]')
    .toggleClass('epoch-aggregated-tile-transactions-list-hidden')
})
