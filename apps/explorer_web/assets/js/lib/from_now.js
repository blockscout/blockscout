import $ from 'jquery'
import moment from 'moment'
import router from '../router'

moment.locale(router.locale)

moment.relativeTimeThreshold('M', 12)
moment.relativeTimeThreshold('d', 30)
moment.relativeTimeThreshold('h', 24)
moment.relativeTimeThreshold('m', 60)
moment.relativeTimeThreshold('s', 60)
moment.relativeTimeThreshold('ss', 1)

export function updateAllAges () {
  $('[data-from-now]').each((i, el) => tryUpdateAge(el))
}
function tryUpdateAge (el) {
  if (!el.dataset.fromNow) return

  const timestamp = moment(el.dataset.fromNow)
  if (timestamp.isValid()) updateAge(el, timestamp)
}
function updateAge (el, timestamp) {
  const fromNow = timestamp.fromNow()
  if (fromNow !== el.innerHTML) el.innerHTML = fromNow
}
updateAllAges()

setInterval(updateAllAges, 1000)
