'use strict'

require '../helpers.coffee'
$ = require 'jquery'
_ = require 'underscore'
Point = require '../geom/point.coffee'
Rect = require '../geom/rect.coffee'
settings = require '../settings.coffee'
require('jquery-mousewheel') $

METHODS = [
  'click'
  'mousedown'
  'mouseup'
  'mousemove'
  'mouseout'
  'mousewheel'
  'contextmenu'
]

class Tool
  constructor: (@visualizer, autobind) ->
    @ctx = @visualizer.ctx
    @canvas = @ctx.canvas
    @_scale = 1
    @screenCenter = new Point @canvas.width / 2, @canvas.height / 2
    @center = new Point @canvas.width / 2, @canvas.height / 2
    @isBound = false
    @bind() if autobind

  # Comment-David: the same property is in zoomer.coffee
  @property 'scale',
    get: -> @_scale
    set: (scale) -> @zoom scale, @screenCenter

  # Comment-David: the same method is in zoomer.coffee
  zoom: (k, zoomCenter) ->
    k ?= 1
    offset = @center.subtract zoomCenter
    @center = zoomCenter.add offset.mult k / @_scale
    @_scale = k

  # Comment-David: the same method is in zoomer.coffee
  moveCenter: (offset) ->
    @center = @center.add offset

  # Comment-David: the same method is in zoomer.coffee
  mousewheel: (e) =>
    offset = e.deltaY * e.deltaFactor
    zoomFactor = 2 ** (0.001 * offset)
    @zoom @scale * zoomFactor, @getPoint e
    e.preventDefault()

  bind: ->
    @isBound = true
    for method in METHODS when @[method]?
      $(@canvas).on method, @[method]

  unbind: ->
    @isBound = false
    for method in METHODS when @[method]?
      $(@canvas).off method, @[method]

  toggleState: ->
    if @isBound then @unbind() else @bind()

  draw: ->

  getPoint: (e) ->
    # Comment-David: @canvas.offsetLeft and @canvas.offsetTop are 0
    new Point e.pageX - @canvas.offsetLeft, e.pageY - @canvas.offsetTop # original

  getCell: (e) ->
    @visualizer.zoomer.toCellCoords @getPoint e

  getHoveredIntersection: (cell) ->
    intersections = @visualizer.world.intersections.all()
    for id, intersection of intersections
      return intersection if intersection.rect.containsRect cell

module.exports = Tool
