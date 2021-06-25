import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import numeral from 'numeral'

const weiToEtherConverter = (element, event) => {
  const weiUnit = new BigNumber('1000000000000000000')
  const $element = $(element)
  const $conversionTextWei = $element.find('[data-conversion-text-wei]')
  const $conversionTextEth = $element.find('[data-conversion-text-eth]')
  const $conversionUnit = $element.find('[data-conversion-unit]')
  const originalValueStr = $conversionUnit.data('original-value')
  const unitVal = new BigNumber(numeral(originalValueStr).value())
  const weiVal = unitVal.dividedBy(weiUnit)

  if (event.target.checked) {
    $conversionTextWei.removeClass('d-inline-block').addClass('d-none')
    $conversionTextEth.removeClass('d-none').addClass('d-inline-block')
    $conversionUnit.html(weiVal.toFixed() > 0 ? String(weiVal.toFixed()) : numeral(weiVal).format('0[.000000000000000000]'))
  } else {
    $conversionTextWei.removeClass('d-none').addClass('d-inline-block')
    $conversionTextEth.removeClass('d-inline-block').addClass('d-none')
    $conversionUnit.html(originalValueStr)
  }
}

$('[data-smart-contract-functions]').on('change', '[data-wei-ether-converter]', function (event) {
  weiToEtherConverter(this, event)
})
