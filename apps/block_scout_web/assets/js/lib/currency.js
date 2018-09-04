import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import { BigNumber } from 'bignumber.js'
import socket from '../socket'

export function formatUsdValue (value) {
  if (value === 0) return '$0.000000 USD'
  if (value < 0.000001) return `${window.localized['Less than']} $0.000001 USD`
  if (value < 1) return `$${numeral(value).format('0.000000')} USD`
  if (value < 100000) return `$${numeral(value).format('0,0.00')} USD`
  return `$${numeral(value).format('0,0')} USD`
}

function weiToEther (wei) {
  return new BigNumber(wei).dividedBy('1000000000000000000').toNumber()
}

function etherToUSD (ether, usdExchangeRate) {
  return new BigNumber(ether).multipliedBy(usdExchangeRate).toNumber()
}

function formatAllUsdValues () {
  $('[data-usd-value]').each((i, el) => {
    el.innerHTML = formatUsdValue(el.dataset.usdValue)
  })
}
formatAllUsdValues()

function tryUpdateCalculatedUsdValues (el, usdExchangeRate = el.dataset.usdExchangeRate) {
  if (!el.dataset.hasOwnProperty('weiValue')) return
  const ether = weiToEther(el.dataset.weiValue)
  const usd = etherToUSD(ether, usdExchangeRate)
  const formattedUsd = formatUsdValue(usd)
  if (formattedUsd !== el.innerHTML) el.innerHTML = formattedUsd
}
function updateAllCalculatedUsdValues (usdExchangeRate) {
  $('[data-usd-exchange-rate]').each((i, el) => tryUpdateCalculatedUsdValues(el, usdExchangeRate))
}
updateAllCalculatedUsdValues()

export const exchangeRateChannel = socket.channel(`exchange_rate:new_rate`)
exchangeRateChannel.join()
exchangeRateChannel.on('new_rate', (msg) => updateAllCalculatedUsdValues(humps.camelizeKeys(msg).exchangeRate.usdValue))
