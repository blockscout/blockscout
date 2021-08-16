import $ from 'jquery'

const stringContains = (query, string) => {
  return string.toLowerCase().search(query) === -1
}

const hideUnmatchedToken = (query, token) => {
  const $token = $(token)
  const tokenName = $token.data('token-name')
  const tokenSymbol = $token.data('token-symbol')

  if (stringContains(query, tokenName) && stringContains(query, tokenSymbol)) {
    $token.addClass('d-none')
  } else {
    $token.removeClass('d-none')
  }
}

const hideEmptyType = (container) => {
  const $container = $(container)
  const type = $container.data('token-type')
  const countVisibleTokens = $container.children('[data-token-name]:not(.d-none)').length

  if (countVisibleTokens === 0) {
    $container.addClass('d-none')
  } else {
    $(`[data-number-of-tokens-by-type='${type}']`).empty().append(countVisibleTokens)
    $container.removeClass('d-none')
  }
}

export function TokenBalanceDropdownSearch (element, event) {
  const $element = $(element)
  const $tokensCount = $element.find('[data-tokens-count]')
  const $tokens = $element.find('[data-token-name]')
  const $tokenTypes = $element.find('[data-token-type]')
  const query = event.target.value.toLowerCase()

  $tokens.each((_index, token) => hideUnmatchedToken(query, token))
  $tokenTypes.each((_index, container) => hideEmptyType(container))

  $tokensCount.html($tokensCount.html().replace(/\d+/g, $tokens.not('.d-none').length))
}
