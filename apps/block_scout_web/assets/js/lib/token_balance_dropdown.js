import $ from 'jquery'

const tokenBalanceDropdown = (element) => {
  const $element = $(element)
  const $loading = $element.find('[data-loading]')
  const $errorMessage = $element.find('[data-error-message]')
  const apiPath = element.dataset.api_path

  $loading.show()

  $.get(apiPath)
    .done(response => {$element.html(response); console.log(response)})
    .fail(() => {
      $loading.hide()
      $errorMessage.show()
    })
}

$('[data-token-balance-dropdown]').each((_index, element) => tokenBalanceDropdown(element))
