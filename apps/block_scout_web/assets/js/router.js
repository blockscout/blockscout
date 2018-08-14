import Path from 'path-parser'
import URI from 'urijs'
import humps from 'humps'

const { locale } = Path.createPath('/:locale').partialTest(window.location.pathname) || { locale: 'en' }

export default {
  locale,
  when (pattern, { exactPathMatch } = { exactPathMatch: false }) {
    return new Promise((resolve) => {
      const path = Path.createPath(`/:locale${pattern}`)
      const match = exactPathMatch ? path.test(window.location.pathname) : path.partialTest(window.location.pathname)
      if (match) {
        const routeParams = humps.camelizeKeys(match)
        const queryParams = humps.camelizeKeys(URI(window.location).query(true))
        resolve(Object.assign({}, queryParams, routeParams))
      }
    })
  }
}
