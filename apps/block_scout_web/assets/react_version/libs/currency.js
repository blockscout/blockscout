import numeral from 'numeral'

function formatCurrencyValue (value, symbol) {
  symbol = symbol || '$'
  if (value === 0) return `${symbol}0.000000`
  if (value < 0.000001) return `Less than ${symbol}0.000001`
  if (value < 1) return `${symbol}${numeral(value).format('0.000000')}`
  if (value < 100000) return `${symbol}${numeral(value).format('0,0.00')}`
  if (value > 1000000000000) return `${symbol}${numeral(value).format('0.000e+0')}`
  return `${symbol}${numeral(value).format('0,0')}`
}

export function formatUsdValue (value) {
  return `${formatCurrencyValue(value)} USD`
}
