/**
 * @jest-environment jsdom
 */

import $ from 'jquery'

describe('contract output Wei/Ether converter', () => {
  beforeAll(() => {
    document.body.innerHTML = '<div data-smart-contract-functions></div>'
    require('../../../js/lib/smart_contract/wei_ether_converter')
  })

  beforeEach(() => {
    $('[data-smart-contract-functions]').html(
      '<div data-wei-ether-converter>' +
      '<input type="checkbox">' +
      '<span data-conversion-unit></span>' +
      '<span data-conversion-text-wei class="d-inline-block">Wei</span>' +
      '<span data-conversion-text-eth class="d-none">ETH</span>' +
      '</div>'
    )
  })

  function setOriginalValue(value) {
    $('[data-conversion-unit]').attr('data-original-value', value).text(value)
  }

  function toggleConversion(checked) {
    $('input[type=checkbox]').prop('checked', checked).trigger('change')
  }

  test.each([
    ['1,000,000,000,000,000,001', '1.000000000000000001'],
    ['9,007,199,254,740,993', '0.009007199254740993'],
    ['1000000000000000001', '1.000000000000000001'],
    ['115792089237316195423570985008687907853269984665640564039457584007913129639935',
      '115792089237316195423570985008687907853269984665640564039457.584007913129639935'],
    ['1', '0.000000000000000001'],
    ['0', '0.0000000000000000000'],
    ['1,000,000,000,000,000,000', '1']
  ])('converts %s Wei without rounding', (originalValue, expectedEther) => {
    setOriginalValue(originalValue)
    toggleConversion(true)

    expect($('[data-conversion-unit]').text()).toBe(expectedEther)
  })

  test('restores the original grouped value and labels after repeated toggles', () => {
    const originalValue = '1,000,000,000,000,000,001'
    setOriginalValue(originalValue)

    toggleConversion(true)
    expect($('[data-conversion-text-wei]').hasClass('d-none')).toBe(true)
    expect($('[data-conversion-text-eth]').hasClass('d-inline-block')).toBe(true)

    toggleConversion(false)
    expect($('[data-conversion-unit]').text()).toBe(originalValue)
    expect($('[data-conversion-text-wei]').hasClass('d-inline-block')).toBe(true)
    expect($('[data-conversion-text-eth]').hasClass('d-none')).toBe(true)

    toggleConversion(true)
    expect($('[data-conversion-unit]').text()).toBe('1.000000000000000001')
    expect($('[data-conversion-unit]').attr('data-original-value')).toBe(originalValue)
  })
})
