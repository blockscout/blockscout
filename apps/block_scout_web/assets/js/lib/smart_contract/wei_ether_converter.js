import $ from 'jquery'
import { BigNumber } from 'bignumber.js'

const weiToEtherConverter = (element, event) => {
  const weiUnit = new BigNumber('1000000000000000000')
  const $element = $(element)
  const $conversionTextWei = $element.find('[data-conversion-text-wei]')
  const $conversionTextEth = $element.find('[data-conversion-text-eth]')
  const $conversionUnit = $element.find('[data-conversion-unit]')
  let unitVal = new BigNumber($conversionUnit.html())

  if (event.target.checked) {
    $conversionTextWei.hide()
    $conversionTextEth.show()
    unitVal = unitVal.dividedBy(weiUnit)
    $conversionUnit.html(String(unitVal > 0 ? unitVal : unitVal.toFixed(3)))
  } else {
    $conversionTextWei.show()
    $conversionTextEth.hide()
    unitVal = unitVal.multipliedBy(weiUnit)
    $conversionUnit.html(unitVal)
  }
}

$('[data-smart-contract-functions]').on('change', '[data-wei-ether-converter]', function (event) {
  weiToEtherConverter(this, event)
})
