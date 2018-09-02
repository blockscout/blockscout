import $ from 'jquery'

const tokenTransferToggle = (element) => {
  const $element = $(element)
  const $tokenTransferClose = $element.find("[data-selector='token-transfer-close']")
  const $tokenTransferOpen = $element.find("[data-selector='token-transfer-open']")

  $element.on('show.bs.collapse', () => {
    $tokenTransferOpen.addClass('d-none')
    $tokenTransferClose.removeClass('d-none')
  })

  $element.on('hide.bs.collapse', () => {
    $tokenTransferClose.addClass('d-none')
    $tokenTransferOpen.removeClass('d-none')
  })
}

// Initialize the script scoped for each card.
$("[data-selector='token-transfers-toggle']").each((_index, element) => tokenTransferToggle(element))
