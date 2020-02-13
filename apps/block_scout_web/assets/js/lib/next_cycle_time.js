import $ from 'jquery'
import { getCurrentCycleBlocks, getCycleEnd } from './smart_contract/consensus'
import { secondsToDhms, calcCycleLength } from './utils'

function appendTimeToElement (time) {
  $('[data-selector="cycle-end"]').empty().append(secondsToDhms(time))
}

$(async function () {
  let time
  let [cycleStartBlock, cycleEndBlock] = await getCurrentCycleBlocks()
  let cycleEndInSeconds = await getCycleEnd()
  const cycleLength = calcCycleLength(cycleStartBlock, cycleEndBlock)

  function updateCycleTime () {
    if (!time) {
      time = cycleEndInSeconds
      appendTimeToElement(time)
    } else {
      if (cycleEndInSeconds > 0) {
        time = --cycleEndInSeconds
        appendTimeToElement(time)
      } else {
        // when cycle is done, begin cycle from beginning
        cycleEndInSeconds = cycleLength
        time = cycleEndInSeconds
        appendTimeToElement(time)
      }
    }
  }

  setInterval(updateCycleTime, 1000)
})
