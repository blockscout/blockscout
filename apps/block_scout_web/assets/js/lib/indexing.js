import $ from 'jquery'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'

// TODO: handle indexing tokens
function tryUpdateIndexedStatus (el, indexedRatio = el.dataset.indexedRatio, indexingFinished = false) {
  if (indexingFinished) return $("[data-selector='indexed-status']").remove()
  const blocksPercentComplete = numeral(indexedRatio).format('0%')
  let indexedText
  if (blocksPercentComplete === '100%') {
    return $("[data-selector='indexed-status']").remove()
  } else {
    indexedText = `${blocksPercentComplete} ${window.localized['Blocks Indexed']}`
  }
  if (indexedText !== el.innerHTML) el.innerHTML = indexedText
}

export function updateIndexStatus (msg = {}) {
  $('[data-indexed-ratio]').each((i, el) => tryUpdateIndexedStatus(el, msg.ratio, msg.finished))
}
updateIndexStatus()

const indexingChannel = socket.channel('blocks:indexing')
indexingChannel.join()
indexingChannel.on('index_status', (msg) => updateIndexStatus(humps.camelizeKeys(msg)))
