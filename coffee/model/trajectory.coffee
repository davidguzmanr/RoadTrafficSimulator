'use strict'

{min, max} = Math
require '../helpers'
LanePosition = require './lane-position'
Curve = require '../geom/curve'
_ = require 'underscore'
beta = require '@stdlib/random/base/beta'

class Trajectory
  constructor: (@car, lane, position) ->
    position ?= 0
    @current = new LanePosition @car, lane, position
    @current.acquire()
    @current.lane.carsDependent += 1
    @next = new LanePosition @car
    @temp = new LanePosition @car
    @isChangingLanes = false

  @property 'lane',
    get: -> @temp.lane or @current.lane

  @property 'absolutePosition',
    get: -> if @temp.lane? then @temp.position else @current.position

  @property 'relativePosition',
    get: -> @absolutePosition / @lane.length

  @property 'direction',
    get: -> @lane.getDirection @relativePosition

  @property 'coords',
    get: -> @lane.getPoint @relativePosition

  @property 'nextCarDistance',
    get: ->
      a = @current.nextCarDistance
      b = @next.nextCarDistance
      if a.distance < b.distance then a else b

  @property 'distanceToStopLine',
    get: ->
      return @getDistanceToIntersection() if not @canEnterIntersection()
      return Infinity

  @property 'nextIntersection',
    get: -> @current.lane.road.target

  @property 'previousIntersection',
    get: -> @current.lane.road.source

  isValidTurn: ->
    #TODO right turn is only allowed from the right lane
    nextLane = @car.nextLane
    sourceLane = @current.lane
    throw Error 'no road to enter' unless nextLane

    # Gotta fix roads before calculating turnNumber, design failure by the original author

    if sourceLane.road.target != nextLane.road.source
      currentRoad = sourceLane.road
      nextRoad = nextLane.road.oppositeRoad

      if currentRoad.target != nextRoad.source
        currentRoad = sourceLane.road.oppositeRoad
        nextRoad = nextLane.road

      turnNumber = currentRoad.getTurnDirection(nextRoad)
    else
      turnNumber = sourceLane.getTurnDirection(nextLane)

    throw Error 'no U-turns are allowed' if turnNumber is 3
    #Mario-Comment: This causes traffic issues at corners.
    #if turnNumber is 0 and not sourceLane.isLeftmost
    #  throw Error 'no left turns from this lane'
    #if turnNumber is 2 and not sourceLane.isRightmost
    #  throw Error 'no right turns from this lane'
    return true

  canEnterIntersection: ->
    nextLane = @car.nextLane
    sourceLane = @current.lane
    return true unless nextLane
    intersection = @nextIntersection

    # AKA 'invalid roads' error in getTurnDirection (nextLane or sourcelane changed direction since you picked it)
    if sourceLane.road.target != nextLane.road.source
      currentRoad = sourceLane.road
      nextRoad = nextLane.road.oppositeRoad

      if currentRoad.target != nextRoad.source
        currentRoad = sourceLane.road.oppositeRoad;
        nextRoad = nextLane.road;

      turnNumber = currentRoad.getTurnDirection(nextRoad)
      
      laneNumber = @car.chooseLaneNumber(turnNumber, currentRoad)

      nextLane = nextRoad.lanes[laneNumber]
      @car.nextLane = nextRoad.lanes[laneNumber]

    else
      turnNumber = sourceLane.getTurnDirection(nextLane)

    sideId = sourceLane.road.targetSideId
    intersection.controlSignals.state[sideId][turnNumber]

  getDistanceToIntersection: ->
    distance = @current.lane.length - @car.length / 2 - @current.position
    if not @isChangingLanes then max distance, 0 else Infinity

  timeToMakeTurn: (plannedStep = 0) ->
    @getDistanceToIntersection() <= plannedStep

  moveForward: (distance) ->
    distance = max distance, 0
    @current.position += distance
    @next.position += distance
    @temp.position += distance
    if @timeToMakeTurn() and @canEnterIntersection() and @isValidTurn()
      @_startChangingLanes @car.popNextLane(), 0
    tempRelativePosition = @temp.position / @temp.lane?.length
    gap = 2 * @car.length
    if @isChangingLanes and @temp.position > gap and not @current.free
      @current.release()
    if @isChangingLanes and @next.free and
    @temp.position + gap > @temp.lane?.length
      @next.acquire()
    if @isChangingLanes and tempRelativePosition >= 1
      @_finishChangingLanes()
    # Comment-Mario: When picking next lane you already know the road to take (invariant) so you merely need to consider all OPEN lanes in said road
    if (@car.nextLane and @car.nextLane.isClosed) or (@current.lane and not @isChangingLanes and not @car.nextLane)
      @car.pickNextLane()

  changeLane: (nextLane) ->
    throw Error 'already changing lane' if @isChangingLanes
    throw Error 'no next lane' unless nextLane?
    throw Error 'next lane == current lane' if nextLane is @lane
    throw Error 'not neighbouring lanes' unless @lane.road is nextLane.road
    nextPosition = @current.position + 3 * @car.length
    # TODO: What to do here? We will comment this for the moment (it will haunt us later)
    # throw Error 'too late to change lane' unless nextPosition < @lane.length
    @_startChangingLanes nextLane, nextPosition

  _getIntersectionLaneChangeCurve: ->

  _getAdjacentLaneChangeCurve: ->
    p1 = @current.lane.getPoint @current.relativePosition
    p2 = @next.lane.getPoint @next.relativePosition
    distance = p2.subtract(p1).length
    direction1 = @current.lane.middleLine.vector.normalized.mult distance * 0.3
    control1 = p1.add direction1
    direction2 = @next.lane.middleLine.vector.normalized.mult distance * 0.3
    control2 = p2.subtract direction2
    curve = new Curve p1, p2, control1, control2

  _getCurve: ->
    # FIXME: race condition due to using relativePosition on intersections
    @_getAdjacentLaneChangeCurve()

  _startChangingLanes: (nextLane, nextPosition) ->
    throw Error 'already changing lane' if @isChangingLanes
    throw Error 'no next lane' unless nextLane?
    @isChangingLanes = true
    @next.lane = nextLane
    @next.position = nextPosition

    curve = @_getCurve()

    @temp.lane = curve
    @temp.position = 0 # @current.lane.length - @current.position
    @next.position -= @temp.lane.length

  _finishChangingLanes: ->
    throw Error 'no lane changing is going on' unless @isChangingLanes
    @isChangingLanes = false
    # Swap
    @current.lane.carsDependent -= 1
    @current.lane.tryOpen()

    @current.lane = @next.lane
    @current.lane.carsDependent += 1

    @current.position = @next.position or 0
    @current.acquire()
    @next.lane = null
    @next.position = NaN
    @temp.lane = null
    @temp.position = NaN
    @current.lane

  release: ->
    @current?.release()
    @next?.release()
    @temp?.release()

module.exports = Trajectory
