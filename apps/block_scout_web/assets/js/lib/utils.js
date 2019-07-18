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

export function showLoader (isTimeout, loader) {
  if (isTimeout) {
    const timeout = setTimeout(function () {
      loader.removeAttr('hidden')
      loader.show()
    }, 1000)
    return timeout
  } else {
    loader.hide()
    return null
  }
}
