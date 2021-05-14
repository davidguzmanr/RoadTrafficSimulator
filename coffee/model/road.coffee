'use strict'

{min, max} = Math
require '../helpers'
_ = require 'underscore'
Lane = require './lane'
settings = require '../settings'

class Road
  constructor: (@source, @target) ->
    @id = _.uniqueId 'road'
    @lanes = []
    @lanesNumber = null
    # Comment-Mario: initializing as null road. Might populate later idk
    @oppositeRoad = null
    @update()

  @copy: (road) ->
    result = Object.create Road::
    _.extend result, road
    result.lanes ?= []
    result

  toJSON: ->
    obj =
      id: @id
      source: @source.id
      target: @target.id

  @property 'length',
    get: -> @targetSide.target.subtract(@sourceSide.source).length

  @property 'leftmostLane',
    get: -> @lanes[@lanesNumber - 1]

  @property 'rightmostLane',
    get: -> @lanes[0]

  getTurnDirection: (other) ->
    # Comment-David: if we comment this 'if' a lot of errors go away...
    throw Error 'invalid roads' if @target isnt other.source

    # Reverse engineering comments

    # Side is an id assigned to each face of the square representing the intersection.
    # 0 - Up, 1 - Right, 2 - Down, 3 - Left
    side1 = @targetSideId       # The side of the intersection I am currently facing
    side2 = other.sourceSideId  # The side of the intersection I want to head towards. (Road to take already decided)

    # 0 - left, 1 - forward, 2 - right -> original comment, we were right lol

    # This function gets the face of the current intersection and the face of the next intersection and tells you whether when you get to the intersection:
    # 0 - You will go left
    # 1 - You will go straight ahead
    # 2 - You will go right
    return turnNumber = (side2 - side1 - 1 + 8) % 4

  update: (known_number_lanes=null) ->
    throw Error 'incomplete road' unless @source and @target

    if known_number_lanes == null
      lanes_proportion = 0.5
    else
      lanes_proportion = known_number_lanes*(0.5/settings.lanesNumber)

    @sourceSideId = @source.rect.getSectorId @target.rect.center()
    # Only half of the road?
    @sourceSide = @source.rect.getSide(@sourceSideId).subsegment 1-lanes_proportion, 1.0
    @targetSideId = @target.rect.getSectorId @source.rect.center()
    # Only half of the road?
    @targetSide = @target.rect.getSide(@targetSideId).subsegment 0, lanes_proportion

    # Comment-David: This allows us to change the number of lanes from the slider and we ignore it when we reduce/add a lane
    if known_number_lanes==null
      @lanesNumber = min(@sourceSide.length, @targetSide.length)                  # removed "| 0" at the end, dunno what it does
      @lanesNumber = max settings.lanesNumber, @lanesNumber / settings.gridSize   # removed "| 0" at the end, dunno what it does

    sourceSplits = @sourceSide.split @lanesNumber, true
    targetSplits = @targetSide.split @lanesNumber
    if not @lanes? or @lanes.length < @lanesNumber
      @lanes ?= []
      for i in [0..@lanesNumber - 1]
        @lanes[i] ?= new Lane sourceSplits[i], targetSplits[i], this
    for i in [0..@lanesNumber - 1]
      @lanes[i].sourceSegment = sourceSplits[i]
      @lanes[i].targetSegment = targetSplits[i]
      @lanes[i].leftAdjacent = @lanes[i + 1]
      @lanes[i].rightAdjacent = @lanes[i - 1]
      @lanes[i].leftmostAdjacent = @lanes[@lanesNumber - 1]
      @lanes[i].rightmostAdjacent = @lanes[0]
      @lanes[i].update()

module.exports = Road
