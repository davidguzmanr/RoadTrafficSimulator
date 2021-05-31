'use strict'

{PI} = Math
require '../helpers'
$ = require 'jquery'
_ = require 'underscore'
chroma = require 'chroma-js'
Point = require '../geom/point'
Rect = require '../geom/rect'
Graphics = require './graphics'
ToolMover = require './mover'
ToolIntersectionMover = require './intersection-mover'
ToolIntersectionBuilder = require './intersection-builder'
ToolRoadBuilder = require './road-builder'
ToolHighlighter = require './highlighter'
Tool = require './tool'
Zoomer = require './zoomer'
settings = require '../settings'

class Visualizer
  constructor: (@world) ->
    @$canvas = $('#canvas')
    @canvas = @$canvas[0]
    @ctx = @canvas.getContext('2d')

    @carImage = new Image()
    @carImage.src = 'images/car.png'

    @updateCanvasSize()
    @zoomer = new Zoomer 4, this, true
    @graphics = new Graphics @ctx
    @tool = new Tool this, true
    @toolRoadbuilder = new ToolRoadBuilder this, true
    @toolIntersectionBuilder = new ToolIntersectionBuilder this, true
    @toolHighlighter = new ToolHighlighter this, true
    @toolIntersectionMover = new ToolIntersectionMover this, true
    @toolMover = new ToolMover this, true
    @_running = false
    @previousTime = 0
    @timeFactor = settings.defaultTimeFactor
    @debug = false

  drawIntersection: (intersection, alpha) ->
    color = intersection.color or settings.colors.intersection
    @graphics.drawRect intersection.rect
    @ctx.lineWidth = 0.4
    @graphics.stroke settings.colors.roadMarking
    @graphics.fillRect intersection.rect, color, alpha

  drawSignals: (road) ->
    lightsColors = [settings.colors.redLight, settings.colors.greenLight]
    intersection = road.target
    segment = road.targetSide
    sideId = road.targetSideId
    lights = intersection.controlSignals.state[sideId]

    @ctx.save()
    @ctx.translate segment.center.x, segment.center.y
    @ctx.rotate (sideId + 1) * PI / 2
    @ctx.scale 1 * segment.length, 1 * segment.length
    # map lane ending to [(0, -0.5), (0, 0.5)]
    if lights[0]
      @graphics.drawTriangle(
        new Point(0.1, -0.2),
        new Point(0.2, -0.4),
        new Point(0.3, -0.2)
      )
      @graphics.fill settings.colors.greenLight
    if lights[1]
      @graphics.drawTriangle(
        new Point(0.3, -0.1),
        new Point(0.5, 0),
        new Point(0.3, 0.1)
      )
      @graphics.fill settings.colors.greenLight
    if lights[2]
      @graphics.drawTriangle(
        new Point(0.1, 0.2),
        new Point(0.2, 0.4),
        new Point(0.3, 0.2)
      )
      @graphics.fill settings.colors.greenLight
    @ctx.restore()
    if @debug
      @ctx.save()
      @ctx.fillStyle = "black"
      @ctx.font = "1px Arial"
      center = intersection.rect.center()
      road_id =
      flipInterval = Math.round(intersection.controlSignals.flipInterval * 100) / 100
      phaseOffset = Math.round(intersection.controlSignals.phaseOffset * 100) / 100
      @ctx.fillText flipInterval + ' ' + phaseOffset, center.x, center.y
      @ctx.restore()

  drawRoad: (road, alpha) ->
    throw Error 'invalid road' if not road.source? or not road.target?
    sourceSide = road.sourceSide
    targetSide = road.targetSide

    if @debug
      @ctx.save()
      @ctx.fillStyle = "red"
      @ctx.font = "1px Arial"
      @ctx.fillText "TEST", -224, 42

    @ctx.save()
    @ctx.lineWidth = 0.4
    leftLine = road.leftmostLane.leftBorder
    @graphics.drawSegment leftLine
    @graphics.stroke settings.colors.roadMiddleLane

    rightLine = road.rightmostLane.rightBorder
    @graphics.drawSegment rightLine
    @graphics.stroke settings.colors.roadMarking
    @ctx.restore()

    @graphics.polyline sourceSide.source, sourceSide.target,
    targetSide.source, targetSide.target
    @graphics.fill settings.colors.road, alpha

    @ctx.save()
    for lane in road.lanes[1..]
      line = lane.rightBorder
      dashSize = 1
      @graphics.drawSegment line
      @ctx.lineWidth = 0.2
      @ctx.lineDashOffset = 1.5 * dashSize
      @ctx.setLineDash [dashSize]
      @graphics.stroke settings.colors.roadMarking
      # Comment-Mario: draw closed lanes as RED
      if lane.isClosed
        @graphics.polyline(lane.sourceSegment.source, lane.sourceSegment.target, lane.targetSegment.source, lane.targetSegment.target)
        @graphics.fill('red', 0.2)
    
    # Comment-David: This add the road-id and number of lanes to the debug feature
    if @debug
      @ctx.save()
      @ctx.fillStyle = "red"
      @ctx.font = "1px Arial"
      @ctx.fillText(road.id + '  ' + (road.sourceSide.source.x + road.targetSide.source.x) / 2 + '  ' + (road.sourceSide.source.y + road.targetSide.source.y) / 2, (road.sourceSide.source.x + road.targetSide.source.x) / 2, (road.sourceSide.source.y + road.targetSide.source.y) / 2);
      @ctx.fillText("#lanes=" + road.lanesNumber, (road.sourceSide.source.x + road.targetSide.source.x) / 2, (road.sourceSide.source.y + road.targetSide.source.y) / 2 + 1)

      # Find the road besides the current road
      _refroads = @world.roads.all()

      for _ref in Object.values(_refroads)
        if _ref.source.id == road.target.id and _ref.target.id == road.source.id
          next_road = _ref

      # This will measure the flux in each road, it will be useful when making the decision of adding more lanes
      flux = 0.0
      next_flux = 0.0
      _refcars = @world.cars.all()

      # Count the number of cars in each road
      for car in Object.values(_refcars)
        if car.trajectory.current._lane.road.id == road.id
          flux += 1

        if car.trajectory.current._lane.road.id == next_road.id
          next_flux += 1

      # This will measure the density according to equations (2) and (3) from
      # https://www.researchgate.net/publication/348225622_Modeling_adaptive_reversible_lanes_A_cellular_automata_approach,
      # we are taking rho = 1

      flux_total = flux + next_flux
      percentage = flux/flux_total
      n_lanes = 3
      n_lanes_next = 3

      density = (n_lanes_next/n_lanes) * (percentage) / (1 - percentage)

      # It happens when one road has cars and the next road is empty, in that case it is better to define it as one
      if density == Infinity
        density = 1
      # The road is empty
      if isNaN(density)
        density = 0

      @ctx.fillText("ρ=" + density.toFixed(3), (road.sourceSide.source.x + road.targetSide.source.x) / 2, (road.sourceSide.source.y + road.targetSide.source.y) / 2 + 2)

    @ctx.restore()


  drawCar: (car) ->
    angle = car.direction
    center = car.coords
    rect = new Rect 0, 0, 1.1 * car.length, 1.7 * car.width
    rect.center new Point 0, 0
    boundRect = new Rect 0, 0, car.length, car.width
    boundRect.center new Point 0, 0

    @graphics.save()
    @ctx.translate center.x, center.y
    @ctx.rotate angle
    l = 0.90 - 0.30 * car.speed / car.maxSpeed
    style = chroma(car.color, 0.8, l, 'hsl').hex()
    # @graphics.drawImage @carImage, rect
    @graphics.fillRect boundRect, style
    @graphics.restore()
    if @debug
      @ctx.save()
      @ctx.fillStyle = "black"
      @ctx.font = "1px Arial"
      @ctx.fillText car.id, center.x, center.y

      if (curve = car.trajectory.temp?.lane)?
        @graphics.drawCurve curve, 0.1, 'red'
      @ctx.restore()

  drawGrid: ->
    gridSize = settings.gridSize
    box = @zoomer.getBoundingBox()
    return if box.area() >= 2000 * gridSize * gridSize
    sz = 0.4

    for i in [box.left()..box.right()] by gridSize
      for j in [box.top()..box.bottom()] by gridSize
        rect = new Rect i - sz / 2, j - sz / 2, sz, sz
        @graphics.fillRect rect, settings.colors.gridPoint

  updateCanvasSize: ->
    if @$canvas.attr('width') isnt $(window).width or
    @$canvas.attr('height') isnt $(window).height
      @$canvas.attr
        width: $(window).width()
        height: $(window).height()

  draw: (time) =>
    delta = (time - @previousTime) || 0
    if delta > 30
      delta = 100 if delta > 100
      @previousTime = time
      @world.onTick @timeFactor * delta / 1000
      @updateCanvasSize()
      @graphics.clear settings.colors.background
      @graphics.save()
      @zoomer.transform()
      @drawGrid()
      for id, intersection of @world.intersections.all()
        @drawIntersection intersection, 0.9
      @drawRoad road, 0.9 for id, road of @world.roads.all()
      @drawSignals road for id, road of @world.roads.all()
      @drawCar car for id, car of @world.cars.all()
      @toolIntersectionBuilder.draw() # TODO: all tools
      @toolRoadbuilder.draw()
      @toolHighlighter.draw()
      @graphics.restore()
    window.requestAnimationFrame @draw if @running

  @property 'running',
    get: -> @_running
    set: (running) ->
      if running then @start() else @stop()

  start: ->
    unless @_running
      @_running = true
      @draw()

  stop: ->
    @_running = false

module.exports = Visualizer
