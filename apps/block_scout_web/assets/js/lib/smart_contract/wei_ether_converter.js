import $ from 'jquery'
import { BigNumber } from 'bignumber.js'
import numeral from 'numeral'

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
    unitVal = unitVal.dividedBy(weiUnit).toNumber()
    $conversionUnit.html(String(unitVal > 0 ? numeral(unitVal).format('0,0') : numeral(unitVal).format('0.0[00000]')))
  } else {
    $conversionTextWei.show()
    $conversionTextEth.hide()
    unitVal = unitVal.multipliedBy(weiUnit).toNumber()
    $conversionUnit.html(String(numeral(unitVal).format('0,0')))
  }
}

$('[data-smart-contract-functions]').on('change', '[data-wei-ether-converter]', function (event) {
  weiToEtherConverter(this, event)
})
