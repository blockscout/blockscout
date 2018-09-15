import $ from 'jquery'

const fetchTransactions = (addressHash) => {
  return $.get(`/address/${addressHash}/ajax/transactions`)
}

const addressTabController = (element) => {
  const $element = $(element)
  const $content = $element.find('[data-tab-content]')
  const $loading = $element.find('[data-loading]')
  const $errorMessage = $element.find('[data-error-message]')

  const addressHash = $element.data('address-hash')
  const page = window.location.pathname

  // Load transactions list with the page url ends with the address hash or /transactions.
  if(page.endsWith('transactions') || page.endsWith(addressHash)) {
    $loading.show()

    fetchTransactions(addressHash)
      .done(response => $content.html(response))
      .fail(() => {
        $loading.hide()
        $errorMessage.show()
      })
  }

  // Load the tab content when the user clicks on it.
  $element.on('click', '[data-tab]', (event) => {
    event.preventDefault()

    const path = event.target.dataset.path

    $loading.show()

    $.get(path)
      .done(response => {
        $content.html(response)
      })
      .fail(() => {
        $loading.hide()
        $errorMessage.show()
      })
  })
}

$('[data-address-tab-controller]').each((_index, element) => addressTabController(element))
