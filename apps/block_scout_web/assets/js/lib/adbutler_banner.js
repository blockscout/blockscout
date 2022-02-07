/* eslint-disable */
import $ from 'jquery'
import { showAd } from './ad.js'

if (showAd()) {
  $('.ad-container').show()
} else {
  $('.ad-container').hide()
}
