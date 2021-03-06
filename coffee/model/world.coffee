'use strict'

{random} = Math
require '../helpers'
_ = require 'underscore'
Car = require './car'
Intersection = require './intersection'
Road = require './road'
Pool = require './pool'
Rect = require '../geom/rect'
Visualizer = require '../visualizer/visualizer'
Tool = require '../visualizer/tool'
settings = require '../settings'

class World
  constructor: ->
    # @tool = new Tool new Visualizer this, true
    @set {}

  @property 'instantSpeed',
    get: ->
      speeds = _.map @cars.all(), (car) -> car.speed
      return 0 if speeds.length is 0
      return (_.reduce speeds, (a, b) -> a + b) / speeds.length

  set: (obj) ->
    obj ?= {}
    @intersections = new Pool Intersection, obj.intersections
    @roads = new Pool Road, obj.roads
    @cars = new Pool Car, obj.cars
    @carsNumber = 0
    @lanesNumber = 3
    @time = 0

  save: ->
    data = _.extend {}, this
    delete data.cars
    localStorage.world = JSON.stringify data

  load: (data) ->
    data = data or localStorage.world
    data = data and JSON.parse data
    return unless data?
    @clear()
    @carsNumber = data.carsNumber or 0
    for id, intersection of data.intersections
      @addIntersection Intersection.copy intersection
    for id, road of data.roads
      road = Road.copy road
      road.source = @getIntersection road.source
      road.target = @getIntersection road.target
      @addRoad road

  generateMap: (minX = -2, maxX = 2, minY = -2, maxY = 2) ->
    @clear()
    intersectionsNumber = (0.8 * (maxX - minX + 1) * (maxY - minY + 1)) | 0
    map = {}
    gridSize = settings.gridSize
    step = 5 * gridSize
    @carsNumber = 100
    @lanesNumber = 3
    while intersectionsNumber > 0
      x = _.random minX, maxX
      y = _.random minY, maxY
      unless map[[x, y]]?
        rect = new Rect step * x, step * y, gridSize, gridSize
        intersection = new Intersection rect
        @addIntersection map[[x, y]] = intersection
        intersectionsNumber -= 1
    for x in [minX..maxX]
      previous = null
      for y in [minY..maxY]
        intersection = map[[x, y]]
        if intersection?
          if random() < 0.9
            if previous != null
              road1 = new Road intersection, previous
              road2 = new Road previous, intersection

              road1.oppositeRoad = road2
              road2.oppositeRoad = road1

              @addRoad road1
              @addRoad road2
          previous = intersection
    for y in [minY..maxY]
      previous = null
      for x in [minX..maxX]
        intersection = map[[x, y]]
        if intersection?
          if random() < 0.9
            if previous != null
              road1 = new Road intersection, previous
              road2 = new Road previous, intersection

              road1.oppositeRoad = road2
              road2.oppositeRoad = road1

              @addRoad road1
              @addRoad road2
          previous = intersection
    null

  changeNumberofLanes: (id=null) ->
    _refroads = @roads.all()

    if id == null
      # Comment-David: pick a random road to change number of lanes
      id = _.sample(@roads.all()).id

    road = _refroads[id]

    # Comment-David: this reduces a lane in one direction
    removed_lane = road.leftmostLane  # equivalent to road.lanes[road.lanesNumbers - 1]
    console.log('LANE CLOSED')
    removed_lane.isClosed = true
    removed_lane.tryOpen();

    return

  # Comment-David: function to stop the traffic in a road
  # Not implemented yet
  StopRoad: ->
    return

  clear: ->
    localStorage.clear()
    @set {}

  onTick: (delta) =>
    throw Error 'delta > 1' if delta > 1
    @time += delta
    @refreshCars()
    for id, intersection of @intersections.all()
      intersection.controlSignals.onTick delta
    for id, car of @cars.all()
      car.move delta
      @removeCar car unless car.alive

  refreshCars: ->
    @addRandomCar() if @cars.length < @carsNumber
    @removeRandomCar() if @cars.length > @carsNumber

  addRoad: (road) ->
    @roads.put road
    road.source.roads.push road
    road.target.inRoads.push road
    road.update()

  getRoad: (id) ->
    @roads.get id

  addCar: (car) ->
    @cars.put car

  getCar: (id) ->
    @cars.get(id)

  removeCar: (car) ->
    @cars.pop car

  addIntersection: (intersection) ->
    @intersections.put intersection

  getIntersection: (id) ->
    @intersections.get id

  addRandomCar: ->
    road = _.sample @roads.all()
    if road?
      lane = _.sample road.lanes
      @addCar new Car lane if lane?

  removeRandomCar: ->
    car = _.sample @cars.all()
    if car?
      @removeCar car

  # Comment-David: the next functions will try to create traffic in a certain directions
  addCarEast: ->
    flag = true
    while flag
      road = _.sample(@roads.all())
      if road != null
        lane = _.sample(road.lanes)
        if lane != null and lane.direction == 0
          flag = false
          @carsNumber += 1
          return @addCar new Car lane

  addCarWest: ->
    flag = true
    while flag
      road = _.sample(@roads.all())
      if road != null
        lane = _.sample(road.lanes)
        if lane != null and lane.direction == Math.PI
          flag = false
          @carsNumber += 1
          return @addCar new Car lane

  addCarNorth: ->
    flag = true
    while flag
      road = _.sample(@roads.all())
      if road != null
        lane = _.sample(road.lanes)
        if lane != null and lane.direction == -Math.PI / 2
          flag = false
          @carsNumber += 1
          return @addCar new Car lane

  addCarSouth: ->
    flag = true
    while flag
      road = _.sample(@roads.all())
      if road != null
        lane = _.sample(road.lanes)
        if lane != null and lane.direction == Math.PI / 2
          flag = false
          @carsNumber += 1
          return @addCar new Car lane

module.exports = World
