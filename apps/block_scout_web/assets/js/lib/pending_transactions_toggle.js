import $ from 'jquery'

const pendingTransactionToggle = (element) => {
  const $element = $(element)
  const $pendingTransactionsClose = $element.find("[data-selector='pending-transactions-close']")
  const $pendingTransactionsOpen = $element.find("[data-selector='pending-transactions-open']")

  $element.on('show.bs.collapse', () => {
    $pendingTransactionsOpen.addClass('d-none')
    $pendingTransactionsClose.removeClass('d-none')
  })

  $element.on('hide.bs.collapse', () => {
    $pendingTransactionsClose.addClass('d-none')
    $pendingTransactionsOpen.removeClass('d-none')
  })
}

// Initialize the script scoped for each instance.
$("[data-selector='pending-transactions-toggle']").each((_index, element) => pendingTransactionToggle(element))
