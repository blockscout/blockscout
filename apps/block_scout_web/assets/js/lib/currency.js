import $ from 'jquery'
import numeral from 'numeral'
import { BigNumber } from 'bignumber.js'

export function formatUsdValue (value) {
  const formattedValue = formatCurrencyValue(value)
  if (formattedValue === 'N/A') {
    return formattedValue
  } else {
    return `${formattedValue} USD`
  }
}

function formatTokenUsdValue (value) {
  return formatCurrencyValue(value, '@')
}

function formatCurrencyValue (value, symbol) {
  symbol = symbol || '$'
  if (isNaN(value)) return 'N/A'
  if (value === 0 || value === '0') return `${symbol}0.00`
  if (value < 0.000001) return `${window.localized['Less than']} ${symbol}0.000001`
  if (value < 1) return `${symbol}${numeral(value).format('0.000000')}`
  if (value < 100000) return `${symbol}${numeral(value).format('0,0.00')}`
  if (value > 1000000000000) return `${symbol}${numeral(value).format('0.000e+0')}`
  return `${symbol}${numeral(value).format('0,0')}`
}

function weiToEther (wei) {
  return new BigNumber(wei).dividedBy('1000000000000000000').toNumber()
}

function etherToUSD (ether, usdExchangeRate) {
  return new BigNumber(ether).multipliedBy(usdExchangeRate).toNumber()
}

export function formatAllUsdValues (root) {
  root = root || $(':root')

  root.find('[data-usd-value]').each((i, el) => {
    el.innerHTML = formatUsdValue(el.dataset.usdValue)
  })
  root.find('[data-token-usd-value]').each((i, el) => {
    el.innerHTML = formatTokenUsdValue(el.dataset.tokenUsdValue)
  })

  return root
}
formatAllUsdValues()

function tryUpdateCalculatedUsdValues (el, usdExchangeRate = el.dataset.usdExchangeRate) {
  // eslint-disable-next-line no-prototype-builtins
  if (!el.dataset.hasOwnProperty('weiValue')) return
  const ether = weiToEther(el.dataset.weiValue)
  const usd = etherToUSD(ether, usdExchangeRate)
  const formattedUsd = formatUsdValue(usd)
  if (formattedUsd !== el.innerHTML) {
    $(el).data('rawUsdValue', usd)
    el.innerHTML = formattedUsd
  }
}

function tryUpdateUnitPriceValues (el, usdUnitPrice = el.dataset.usdUnitPrice) {
  const formattedValue = formatCurrencyValue(usdUnitPrice)
  if (formattedValue !== el.innerHTML) el.innerHTML = formattedValue
}

export function updateAllCalculatedUsdValues (usdExchangeRate) {
  $('[data-usd-exchange-rate]').each((i, el) => tryUpdateCalculatedUsdValues(el, usdExchangeRate))
  $('[data-usd-unit-price]').each((i, el) => tryUpdateUnitPriceValues(el, usdExchangeRate))
}
updateAllCalculatedUsdValues()
