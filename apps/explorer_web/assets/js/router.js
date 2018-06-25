import Path from 'path-parser'
import URI from 'urijs'
import humps from 'humps'

const { locale } = Path.createPath('/:locale').partialTest(window.location.pathname)

export default {
  locale,
  when (pattern) {
    return new Promise((resolve) => {
      const match = Path.createPath(`/:locale${pattern}`).partialTest(window.location.pathname)
      if (match) {
        const routeParams = humps.camelizeKeys(match)
        const queryParams = humps.camelizeKeys(URI(window.location).query(true))
        resolve(Object.assign({}, queryParams, routeParams))
      }
    })
  }
}
