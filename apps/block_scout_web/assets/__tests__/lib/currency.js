/**
 * @jest-environment jsdom
 */

import { formatUsdValue } from '../../js/lib/currency'

test('formatUsdValue', () => {
  window.localized = {
    'Less than': 'Less than'
  }
  expect(formatUsdValue(0)).toEqual('$0.00 USD')
  expect(formatUsdValue(0.0000001)).toEqual('Less than $0.000001 USD')
  expect(formatUsdValue(0.123456789)).toEqual('$0.123 USD')
  expect(formatUsdValue(0.12)).toEqual('$0.120 USD')
  expect(formatUsdValue(1.23456789)).toEqual('$1.235 USD')
  expect(formatUsdValue(1.2)).toEqual('$1.200 USD')
  expect(formatUsdValue(123456.789)).toEqual('$123,457 USD')
})
