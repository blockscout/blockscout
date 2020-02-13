import _ from 'lodash'
import { of } from 'rxjs'
import { delay, tap, mergeMap, repeat } from 'rxjs/operators'

export function batchChannel (func) {
  let msgs = []
  const debouncedFunc = _.debounce(() => {
    func.apply(this, [msgs])
    msgs = []
  }, 1000, { maxWait: 5000 })
  return (msg) => {
    msgs.push(msg)
    debouncedFunc()
  }
}

export function secondsToDhms (seconds) {
  seconds = Number(seconds)
  var floor = Math.floor

  var d = floor(seconds / (3600 * 24))
  var h = floor(seconds % (3600 * 24) / 3600)
  var m = floor(seconds % 3600 / 60)
  var s = Math.floor(seconds % 60)

  var dDisplay = d > 0 ? d + 'd ' : ''
  var hDisplay = h > 0 ? h + 'h ' : ''
  var mDisplay = m > 0 ? m + 'm ' : ''
  var sDisplay = s > 0 ? s + 's' : ''
  return dDisplay + hDisplay + mDisplay + sDisplay
}

export function poll (fn, ms, cb) {
  return of({}).pipe(
    mergeMap(_ => fn()),
    tap(cb),
    delay(ms),
    repeat()
  )
}

export function calcCycleLength (cycleStartBlock, cycleEndBlock) {
  return (cycleEndBlock - cycleStartBlock) * 5
}

export function calcCycleEndPercent (cycleEnd, cycleLength) {
  return 1 - (cycleEnd / cycleLength)
}
