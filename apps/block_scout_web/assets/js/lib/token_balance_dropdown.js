import $ from 'jquery'

const tokenBalanceDropdown = (element) => {
  const $element = $(element)
  const $loading = $element.find('[data-loading]')
  const $errorMessage = $element.find('[data-error-message]')
  const apiPath = element.dataset.api_path

  $loading.show()

  $.get(apiPath)
    .done(response => $element.html(response))
    .fail(() => {
      $loading.hide()
      $errorMessage.show()
    })
}

export function loadTokenBalanceDropdown () {
  $('[data-token-balance-dropdown]').each((_index, element) => tokenBalanceDropdown(element))
}
loadTokenBalanceDropdown()
