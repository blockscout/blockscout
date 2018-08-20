import moment from 'moment'
import numeral from 'numeral'
import 'numeral/locales'
import router from './router'

moment.locale(router.locale)
numeral.locale(router.locale)
