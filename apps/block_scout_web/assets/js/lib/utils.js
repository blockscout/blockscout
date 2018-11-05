import $ from 'jquery'
import _ from 'lodash'

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

export function onScrollBottom (callback) {
  const $window = $(window)
  function infiniteScrollChecker () {
    const scrollHeight = $(document).height()
    const scrollPosition = $window.height() + $window.scrollTop()
    if ((scrollHeight - scrollPosition) / scrollHeight === 0) {
      callback()
    }
  }
  infiniteScrollChecker()
  $window.on('scroll', infiniteScrollChecker)
}
