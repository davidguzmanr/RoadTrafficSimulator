'use strict'

require '../helpers.coffee'
Tool = require './tool.coffee'

class Mover extends Tool
  constructor: ->
    super arguments...
    @startPosition = null

  contextmenu: ->
    false

  click: (e) =>
    if e.ctrlKey
      click_point = @getPoint(e) # da fuc is this doing?

      # Comment-David: we define the middle point of each road and then we find the road
      # closest to the point 'e' where we clicked
      closest_road_distance = Infinity
      closest_road_id = null
      _refroads = @visualizer.world.roads.all()
      for _ref in Object.values(_refroads)
          x_middle = (_ref.sourceSide.source.x + _ref.targetSide.source.x) / 2
          y_middle = (_ref.sourceSide.source.y + _ref.targetSide.source.y) / 2
          distance = (click_point.x - x_middle)**2 + (click_point.y - y_middle)**2

          if distance < closest_road_distance
            closest_road_distance = distance
            closest_road_id = _ref.id

      console.log('Click point: (' + click_point.x + ', ' + click_point.y + '). Closest road: ' + closest_road_id)

      # Hacemos el cambio en ese road
      @visualizer.world.changeNumberofLanes(closest_road_id)

  mousedown: (e) =>
    @startPosition = @getPoint e
    e.stopImmediatePropagation()

  mouseup: =>
    @startPosition = null

  mousemove: (e) =>
    if @startPosition
      offset = @getPoint(e).subtract(@startPosition)
      @visualizer.zoomer.moveCenter offset
      @startPosition = @getPoint e

  mouseout: =>
    @startPosition = null



module.exports = Mover
