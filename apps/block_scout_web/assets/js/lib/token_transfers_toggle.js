import $ from 'jquery'

$(document.body).on('click', '[data-selector="token-transfer-open"]', event => {
  const $tokenTransferOpen = event.target
  const $parent = $tokenTransferOpen.parentElement
  const $tokenTransferClose = $parent.querySelector("[data-selector='token-transfer-close']")
  $tokenTransferOpen.classList.add('d-none')
  $tokenTransferClose.classList.remove('d-none')
})

$(document.body).on('click', '[data-selector="token-transfer-close"]', event => {
  const $tokenTransferClose = event.target
  const $parent = $tokenTransferClose.parentElement
  const $tokenTransferOpen = $parent.querySelector("[data-selector='token-transfer-open']")
  $tokenTransferClose.classList.add('d-none')
  $tokenTransferOpen.classList.remove('d-none')
})
