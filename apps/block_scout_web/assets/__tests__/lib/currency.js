/**
 * @jest-environment jsdom
 */

import { formatUsdValue } from '../../js/lib/currency'

test('formatUsdValue', () => {
  expect(formatUsdValue(0)).toEqual('$0.00 USD')
  expect(formatUsdValue(0.0000001)).toEqual('< $0.000001 USD')
  expect(formatUsdValue(0.123456789)).toEqual('$0.123457 USD')
  expect(formatUsdValue(0.1234)).toEqual('$0.123400 USD')
  expect(formatUsdValue(1.23456789)).toEqual('$1.23 USD')
  expect(formatUsdValue(1.2)).toEqual('$1.20 USD')
  expect(formatUsdValue(123456.789)).toEqual('$123,457 USD')
})
