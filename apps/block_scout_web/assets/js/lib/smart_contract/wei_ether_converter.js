import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import numeral from 'numeral'

const weiToEtherConverter = (element, event) => {
  const weiUnit = new BigNumber('1000000000000000000')
  const $element = $(element)
  const $conversionTextWei = $element.find('[data-conversion-text-wei]')
  const $conversionTextEth = $element.find('[data-conversion-text-eth]')
  const $conversionUnit = $element.find('[data-conversion-unit]')
  let unitVal = new BigNumber(numeral($conversionUnit.html()).value())

  if (event.target.checked) {
    $conversionTextWei.removeClass('d-inline-block').hide()
    $conversionTextEth.removeClass('d-none').show()
    unitVal = unitVal.dividedBy(weiUnit)
    $conversionUnit.html(unitVal.toFixed() > 0 ? unitVal.toFixed() : numeral(unitVal).format('0[.000000000000000000]'))
  } else {
    $conversionTextWei.addClass('d-inline-block')
    $conversionTextEth.addClass('d-none')
    unitVal = unitVal.multipliedBy(weiUnit)
    $conversionUnit.html(unitVal.toFixed())
  }
}

$('[data-smart-contract-functions]').on('change', '[data-wei-ether-converter]', function (event) {
  weiToEtherConverter(this, event)
})
