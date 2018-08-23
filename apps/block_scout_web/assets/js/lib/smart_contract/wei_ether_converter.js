import $ from 'jquery'
import { BigNumber } from 'bignumber.js'

const weiToEtherConverter = (element, event) => {
  const weiUnit = '1000000000000000000'
  const $element = $(element)
  const $conversionTextWei = $element.find('[data-conversion-text-wei]')
  const $conversionTextEth = $element.find('[data-conversion-text-eth]')
  const $conversionUnit = $element.find('[data-conversion-unit]')
  let unitVal = new BigNumber($conversionUnit.html())

  if (event.target.checked) {
    $conversionTextWei.css({display: 'none'})
    $conversionTextEth.css({display: 'inline-block'})
    unitVal = unitVal / new BigNumber(weiUnit)
    $conversionUnit.html(String(unitVal > 0 ? unitVal : unitVal.toFixed(3)))
  } else {
    $conversionTextWei.css({display: 'inline-block'})
    $conversionTextEth.css({display: 'none'})
    unitVal = unitVal * new BigNumber(weiUnit)
    $conversionUnit.html(unitVal)
  }
}

$('[data-smart-contract-functions]').on('change', '[data-wei-ether-converter]', function (event) {
  weiToEtherConverter(this, event)
})
