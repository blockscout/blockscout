import $ from 'jquery'
import { formatAllUsdValues, formatUsdValue } from './currency'
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
      const tokensCount = $('[data-dropdown-token-balance-test]').length
      const $addressTokenWorth = $('[data-test="address-tokens-worth"]')
      const tokensDsName = (tokensCount > 1) ? ' tokens' : ' token'
      $('[data-test="address-tokens-panel-tokens-worth"]').text(`${$addressTokenWorth.text()} | ${tokensCount} ${tokensDsName}`)
      const $addressTokensPanelNativeWorth = $('[data-test="address-tokens-panel-native-worth"]')
      const rawUsdValue = $addressTokensPanelNativeWorth.children('span').data('raw-usd-value')
      const rawUsdTokensValue = $addressTokenWorth.data('usd-value')
      const formattedFullUsdValue = formatUsdValue(parseFloat(rawUsdValue) + parseFloat(rawUsdTokensValue))
      $('[data-test="address-tokens-panel-net-worth"]').text(formattedFullUsdValue)
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
