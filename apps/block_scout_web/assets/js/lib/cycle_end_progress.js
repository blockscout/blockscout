import $ from 'jquery'
import 'jquery-circle-progress'

class ProgressCircle {
  constructor ($el) {
    this.$el = $el
    this.init()
  }

  init () {
    $(this.$el).circleProgress({
      value: 0,
      size: 150,
      thickness: 12,
      emptyFill: '#49687c',
      lineCap: 'round'
    }).on('circle-animation-progress', function (event, progress, stepValue) {
      $(this).find('.progress-value').html(`${Math.trunc(stepValue * 100)}%`)
    })
  }

  set (value) {
    $(this.$el).circleProgress('value', value)
  }
}

export function createCycleEndProgressCircle ($el) {
  return new ProgressCircle($el)
}
