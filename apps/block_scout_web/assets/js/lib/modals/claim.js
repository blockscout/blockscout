import $ from 'jquery'
import humps from 'humps'
import {store} from '../pages/stakes.js'
import * as modals from './utils.js'

window.openClaimModal = async function (poolAddress) {
  let modal = '#claimModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)
    let relation = humps.camelizeKeys(response.relation)
    let tokenSymbol = store.getState().tokenSymbol

    modals.setProgressInfo(modal, pool)

    $(`${modal} [ordered-amount]`).text(`${relation.orderedWithdraw} ${tokenSymbol}`)
    $(`${modal} form`).unbind('submit')
    $(`${modal} form`).on('submit', _ => modals.claimWithdraw(modal, poolAddress))

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    modals.openErrorModal('Error', 'Something went wrong')
  }
}
