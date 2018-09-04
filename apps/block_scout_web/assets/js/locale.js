import moment from 'moment'
import numeral from 'numeral'
import 'numeral/locales'

export const locale = 'en'

moment.locale(locale)
numeral.locale(locale)
