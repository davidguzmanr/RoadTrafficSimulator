'use strict'

require '../helpers'
_ = require 'underscore'
Segment = require '../geom/segment'

class Lane
  constructor: (@sourceSegment, @targetSegment, @road, @laneIndex) ->
    @leftAdjacent = null
    @rightAdjacent = null
    @leftmostAdjacent = null
    @rightmostAdjacent = null
    @isClosed = false
    @isChanged = false
    @carsDependent = 0
    # Comment-Mario: carsPositions was an object, changed to array so we can access length (hope nothing breaks)
    @carsPositions = []
    @update()

  toJSON: ->
    obj = _.extend {}, this
    delete obj.carsPositions
    obj

  @property 'sourceSideId',
    get: -> @road.sourceSideId

  @property 'targetSideId',
    get: -> @road.targetSideId

  @property 'isRightmost',
    get: -> this is @.rightmostAdjacent

  @property 'isLeftmost',
    get: -> this is @.leftmostAdjacent

  @property 'leftBorder',
    get: ->
      new Segment @sourceSegment.source, @targetSegment.target

  @property 'rightBorder',
    get: ->
      new Segment @sourceSegment.target, @targetSegment.source

  update: ->
    @middleLine = new Segment @sourceSegment.center, @targetSegment.center
    @length = @middleLine.length
    @direction = @middleLine.direction

  # Comment-Mario: Tries to open the lane if it is closed
  tryOpen: ->
    #TODO: Do this for all lanes in road.
    road = @road
    if @isClosed == false
      return true

    # If it is finally empty, we can proceed with
    if @carsDependent == 0
       road.lanesNumber -= 1
       road.lanes = road.lanes.slice(0, road.lanesNumber)
       road.update(road.lanesNumber)

       # Comment-David: This adds a lane in the other direction
       # The problem is here? Dunno
       next_road = road.oppositeRoad
       new_lanes = next_road.lanes
      
       console.log("old direction:")
       console.log(@direction)

       # Change the direction and other attributes to make it go in the other direction
       @direction += Math.PI;

       console.log("new direction")
       console.log(@direction)
       console.log("new_fixed")
       console.log(((@direction + 2*Math.PI)% (2*Math.PI)))

       @road = next_road

       # removed_lane.sourceSegment, removed_lane.targetSegment = removed_lane.targetSegment, removed_lane.sourceSegment;

       # Add removed_lane at [0], i.e., rightmostLane

       #proper_direction = ((@direction + 2*Math.PI)% (2*Math.PI))

       #if(proper_direction == 0 || proper_direction == Math.PI || proper_direction == (Math.PI/2) || proper_direction == (3*Math.PI/2))
       new_lanes.push(@)
       #else
       #  new_lanes.unshift(@) #Problem is here. Still happens when a W->E changes to E->W
       #N->S to S->N works fine, but S->N to N->S probably does not.
       @laneIndex = next_road.lanesNumber
       next_road.lanes = new_lanes
       # next_road.rightmostLane = removed_lane;
       next_road.lanesNumber += 1
       next_road.update(next_road.lanesNumber)

       # For debug purposes, no real logic behind it.
       @isChanged = true
       @isClosed = false
       console.log('LANE OPENED')
       return true

    return false

  getTurnDirection: (other) ->
    return @road.getTurnDirection other.road

  getDirection: ->
    @direction

  getPoint: (a) ->
    @middleLine.getPoint a

  addCarPosition: (carPosition) ->
    throw Error 'car is already here' if carPosition.id of @carsPositions
    @carsPositions[carPosition.id] = carPosition

  removeCar: (carPosition) ->
    throw Error 'removing unknown car' unless carPosition.id of @carsPositions
    ret = delete @carsPositions[carPosition.id]
    # Comment-David: Kinda inefficient? Dunno
    @tryOpen()
    return ret

  getNext: (carPosition) ->
    throw Error 'car is on other lane' if carPosition.lane isnt this
    next = null
    bestDistance = Infinity
    for id, o of @carsPositions
      distance = o.position - carPosition.position
      if not o.free and 0 < distance < bestDistance
        bestDistance = distance
        next = o
    next

module.exports = Lane
