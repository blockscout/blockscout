import $ from 'jquery'
import humps from 'humps'
import moment from 'moment'
import {store} from '../pages/stakes.js'
import * as modals from './utils.js'

window.openPoolInfoModal = async function (poolAddress) {
  let modal = '#poolInfoModal'
  try {
    let response = await $.getJSON('/staking_pool', { 'pool_hash': poolAddress })
    let pool = humps.camelizeKeys(response.pool)

    $(`${modal} [staking-address]`).text(pool.stakingAddressHash)
    $(`${modal} [mining-address]`).text(pool.miningAddressHash)
    $(`${modal} [self-staked]`).text(pool.selfStakedAmount)
    $(`${modal} [delegators-staked]`).text(pool.stakedAmount)
    $(`${modal} [stakes-ratio]`).text(`${pool.stakedRatio || 0.00} %`)
    $(`${modal} [reward-percent]`).text(`${pool.blockReward || 0.00} %`)
    $(`${modal} [was-validator]`).text(pool.wasValidatorCount)
    $(`${modal} [was-banned]`).text(pool.wasBannedCount)

    if (pool.isBanned) {
      let currentBlock = store.getState().blocksCount
      let blocksLen = pool.bannedUntil - currentBlock
      let blockTime = $('[data-page="stakes"]').data('average-block-time')
      let banDuring = blockTime * blocksLen
      var dt = moment().add(banDuring, 'seconds').format('D MMM Y')

      $(`${modal} [unban-date]`).text(`Banned until block #${pool.bannedUntil} (${dt})`)
    } else {
      $(`${modal} [unban-date]`).text('-')
    }
    $(`${modal} [likelihood]`).text(`${pool.likelihood || 0.00} %`)
    $(`${modal} [delegators-count]`).text(pool.delegatorsCount)

    $(modal).modal()
  } catch (e) {
    $(modal).modal()
    modals.openErrorModal('Error', 'Something went wrong')
  }
}
