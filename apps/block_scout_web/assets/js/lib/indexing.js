import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'

function tryUpdateIndexedStatus (el, indexedRatio = el.dataset.indexedRatio, indexingFinished = false) {
  if (indexingFinished) return $("[data-selector='indexed-status']").remove()
  let indexedText
  if (parseInt(indexedRatio) === 1.0) {
    indexedText = window.localized['Indexing Tokens']
  } else {
    indexedText = `${numeral(indexedRatio).format('0%')} ${window.localized['Blocks Indexed']}`
  }
  if (indexedText !== el.innerHTML) el.innerHTML = indexedText
}

let currentIndexedRatio
let indexingFinished
export function updateIndexStatus (msg) {
  currentIndexedRatio = _.get(msg, 'ratio')
  indexingFinished = _.get(msg, 'finished')
  $('[data-indexed-ratio]').each((i, el) => tryUpdateIndexedStatus(el, currentIndexedRatio, indexingFinished))
}
updateIndexStatus()

export const indexingChannel = socket.channel(`blocks:indexing`)
indexingChannel.join()
indexingChannel.on('index_status', (msg) => updateIndexStatus(humps.camelizeKeys(msg)))
