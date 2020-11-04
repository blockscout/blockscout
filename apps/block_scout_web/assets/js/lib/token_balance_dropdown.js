import $ from 'jquery'
import { formatAllUsdValues } from './currency'
import { TokenBalanceDropdownSearch } from './token_balance_dropdown_search'

const tokenBalanceDropdown = (element) => {
  const $element = $(element)
  const $loading = $element.find('[data-loading]')
  const $errorMessage = $element.find('[data-error-message]')
  const apiPath = element.dataset.api_path

  $.get(apiPath)
    .done(response => {
      const responseHtml = formatAllUsdValues($(response))
      $element.html(responseHtml)
    })
    .fail(() => {
      $loading.hide()
      $errorMessage.show()
    })
}

export function loadTokenBalanceDropdown () {
  $('[data-token-balance-dropdown]').each((_index, element) => tokenBalanceDropdown(element))

  $('[data-token-balance-dropdown]').on('hidden.bs.dropdown', _event => {
    $('[data-filter-dropdown-tokens]').val('').trigger('input')
  })

  $('[data-token-balance-dropdown]').on('input', function (event) {
    TokenBalanceDropdownSearch(this, event)
  })
}
