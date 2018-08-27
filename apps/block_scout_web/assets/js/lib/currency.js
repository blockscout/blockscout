import numeral from 'numeral'

export function formatUsdValue (value) {
  if (value < 0.000001) return '< $0.000001 USD'
  if (value < 1) return `$${numeral(value).format('0.000000')} USD`
  if (value < 100000) return `$${numeral(value).format('0,0.00')} USD`
  return `$${numeral(value).format('0,0')} USD`
}
