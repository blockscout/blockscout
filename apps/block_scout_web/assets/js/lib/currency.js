import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import { BigNumber } from 'bignumber.js'
import socket from '../socket'

export function formatUsdValue (value) {
  return `${formatCurrencyValue(value)} USD`
}

export function formatCGValue (value) {
  return `${formatCurrencyValue(value, '')} cGLD`
}

function formatTokenUsdValue (value) {
  return formatCurrencyValue(value, '@')
}

function formatCurrencyValue (value, symbol) {
  symbol = symbol === undefined ? '$' : symbol
  if (value === 0) return `${symbol}0.000000`
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
  root.find('[data-cg-value]').each((i, el) => {
    el.innerHTML = formatCGValue(el.dataset.usdValue)
  })
  root.find('[data-token-usd-value]').each((i, el) => {
    el.innerHTML = formatTokenUsdValue(el.dataset.tokenUsdValue)
  })

  return root
}
formatAllUsdValues()

function tryUpdateCalculatedUsdValues (el, usdExchangeRate = el.dataset.usdExchangeRate) {
  if (!el.dataset.hasOwnProperty('weiValue')) return
  const ether = weiToEther(el.dataset.weiValue)
  const usd = etherToUSD(ether, usdExchangeRate)
  const formattedUsd = formatUsdValue(usd)
  if (formattedUsd !== el.innerHTML) el.innerHTML = formattedUsd
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

export const exchangeRateChannel = socket.channel(`exchange_rate:new_rate`)
exchangeRateChannel.join()
exchangeRateChannel.on('new_rate', (msg) => updateAllCalculatedUsdValues(humps.camelizeKeys(msg).exchangeRate.usdValue))
