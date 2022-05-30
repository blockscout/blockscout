import $ from 'jquery'
import moment from 'moment'

moment.relativeTimeThreshold('M', 12)
moment.relativeTimeThreshold('d', 30)
moment.relativeTimeThreshold('h', 24)
moment.relativeTimeThreshold('m', 60)
moment.relativeTimeThreshold('s', 60)
moment.relativeTimeThreshold('ss', 1)

export function updateAllAges ($container = $(document)) {
  $container.find('[data-from-now]').each((i, el) => tryUpdateAge(el))
  return $container
}
function tryUpdateAge (el) {
  if (!el.dataset.fromNow) return

  const timestamp = moment(el.dataset.fromNow)
  if (timestamp.isValid()) updateAge(el, timestamp)
}
function updateAge (el, timestamp) {
  let fromNow = timestamp.fromNow()
  // show the exact time only for transaction details page. Otherwise, short entry
  const elInTile = el.hasAttribute('in-tile')
  if ((window.location.pathname.includes('/tx/') || window.location.pathname.includes('/block/') || window.location.pathname.includes('/blocks/')) && !elInTile) {
    const browserLocale = window.navigator.userLanguage || window.navigator.language
    const date = timestamp.toDate()

    if (browserLocale && typeof date.toLocaleString === 'function') {
      fromNow = `${fromNow} | ${date.toLocaleString(
        browserLocale, {
          timeZone: 'UTC'
        }
      )} UTC`
    } else {
      fromNow = `${fromNow} | ${timestamp.toString()}`
    }
  }
  if (fromNow !== el.innerHTML) el.innerHTML = fromNow
}
updateAllAges()

setInterval(updateAllAges, 1000)
