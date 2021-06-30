'use strict'

{max, min, random, sqrt} = Math
require '../helpers'
_ = require 'underscore'
settings = require '../settings'
Trajectory = require './trajectory'
beta = require '@stdlib/random/base/beta'
binomial = require '@stdlib/random/base/binomial'

class Car
  constructor: (lane, position) ->

    # Comment-David: we will add the vehicles in this proportion: cars-80%, buses-15%, bikes-5%.
    # Cars will be different colors, buses will be green and bikes red/orange. They will have different dimensions
    type_of_car = random()
    total_prob = settings.probCar + settings.probBus + settings.probBike
    vehicle_probability_dist = [settings.probCar/total_prob, settings.probBus/total_prob, settings.probBike/total_prob]
    @fixed_positioning = true
    @known_fixed_position = null

    if type_of_car < vehicle_probability_dist[0]
      @id = _.uniqueId 'car'
      @color = (300 + 240 * random() | 0) % 360
      @_speed = 0
      @width = 1.7
      @length = 3 + 2 * random()
      @maxSpeed = 30
      @s0 = 2
      @timeHeadway = 1.5
      @maxAcceleration = 1
      @maxDeceleration = 3
      @trajectory = new Trajectory this, lane, position
      @alive = true
      @preferedLane = null

    else if type_of_car > vehicle_probability_dist[0] and type_of_car < vehicle_probability_dist[1]
      @id = _.uniqueId 'car'
      @color = (100  | 0) % 360
      @_speed = 0
      @width = 2.0
      @length = 8.0
      # Buses will be slower than the cars
      @maxSpeed = 20
      @s0 = 2
      @timeHeadway = 1.5
      @maxAcceleration = 0.75
      @maxDeceleration = 2
      @trajectory = new Trajectory this, lane, position
      @alive = true
      @preferedLane = null

    else
      @id = _.uniqueId 'car'
      @color = (10  | 0) % 360
      @_speed = 0
      @width = 0.5
      @length = 1.5
      # Bikes will be the slowest
      @maxSpeed = 5
      @s0 = 2
      @timeHeadway = 1.5
      @maxAcceleration = 0.5
      @maxDeceleration = 1
      @trajectory = new Trajectory this, lane, position
      @alive = true
      @preferedLane = null

  @property 'coords',
    get: -> @trajectory.coords

  @property 'speed',
    get: -> @_speed
    set: (speed) ->
      speed = 0 if speed < 0
      speed = @maxSpeed if speed > @maxSpeed
      @_speed = speed

  @property 'direction',
    get: -> @trajectory.direction

  release: ->
    @trajectory.release()

  getAcceleration: ->
    nextCarDistance = @trajectory.nextCarDistance
    distanceToNextCar = max nextCarDistance.distance, 0
    a = @maxAcceleration
    b = @maxDeceleration
    deltaSpeed = (@speed - nextCarDistance.car?.speed) || 0
    freeRoadCoeff = (@speed / @maxSpeed) ** 4
    distanceGap = @s0
    timeGap = @speed * @timeHeadway
    breakGap = @speed * deltaSpeed / (2 * sqrt a * b)
    safeDistance = distanceGap + timeGap + breakGap
    busyRoadCoeff = (safeDistance / distanceToNextCar) ** 2
    safeIntersectionDistance = 1 + timeGap + @speed ** 2 / (2 * b)
    intersectionCoeff =
    (safeIntersectionDistance / @trajectory.distanceToStopLine) ** 2
    coeff = 1 - freeRoadCoeff - busyRoadCoeff - intersectionCoeff
    return @maxAcceleration * coeff

  move: (delta) ->
    acceleration = @getAcceleration()
    @speed += acceleration * delta

    if not @trajectory.isChangingLanes and @nextLane
      currentLane = @trajectory.current.lane
      currentRoad = @trajectory.current.lane.road

      # If the lane you were going towards changed direction
      if currentLane.road.target != @nextLane.road.source
        currentRoad = currentLane.road;
        nextRoad = @nextLane.road.oppositeRoad

        if currentRoad.target != nextRoad.source
          currentRoad = currentLane.road.oppositeRoad
          nextRoad = @nextLane.road

        turnNumber = currentLane.getTurnDirection @nextLane

        laneNumber = @chooseLaneNumber(turnNumber, nextRoad)

        @nextLane = nextRoad.lanes[laneNumber]
        @trajectory.nextLane = nextRoad.lanes[laneNumber]

      # IDK if this will happen, just covering my bases
      else if @nextLane.isClosed
        nextRoad = @nextLane.road
        turnNumber = currentRoad.getTurnDirection(nextRoad)
        
        laneNumber = @chooseLaneNumber(turnNumber, nextRoad)

        @nextLane = nextRoad.lanes[laneNumber]
        @trajectory.nextLane = nextRoad.lanes[laneNumber]

      else
        turnNumber = currentLane.getTurnDirection(@nextLane)
      
    #Comment-Mario: Hilariously broken. Must fix
    #Idea: Choose a lane and then move towards it.
    if @fixed_positioning == false and not @trajectory.isChangingLanes
      if not @known_fixed_position
        currentRoad = @trajectory.current.lane.road
        preferedLane = @chooseLaneNumber(turnNumber, currentRoad)
        @known_fixed_position = preferedLane
      if preferedLane < currentLane.laneIndex
        @trajectory.changeLane currentLane.rightAdjacent
      else if preferedLane > currentLane.laneIndex
        @trajectory.changeLane currentLane.leftAdjacent
      else
        @fixed_positioning = true
        @known_fixed_position = null

    step = @speed * delta + 0.5 * acceleration * delta ** 2
    # TODO: hacks, should have changed speed
    console.log 'bad IDM' if @trajectory.nextCarDistance.distance < step

    if @trajectory.timeToMakeTurn(step)
      return @alive = false if not @nextLane?
    @trajectory.moveForward step

  pickNextRoad: ->
    intersection = @trajectory.nextIntersection
    currentLane = @trajectory.current.lane
    possibleRoads = intersection.roads.filter (x) ->
      x.target isnt currentLane.road.source
    return null if possibleRoads.length is 0
    nextRoad = _.sample possibleRoads

  
  pickNextLane: ->
#     throw Error 'next lane is already chosen' if @nextLane
    @nextLane = null
    nextRoad = @pickNextRoad()
    return null if not nextRoad
    # throw Error 'can not pick next road' if not nextRoad
    turnNumber = @trajectory.current.lane.road.getTurnDirection nextRoad # Calculate turn direction (which road to go to)
    
    laneNumber = @chooseLaneNumber(turnNumber, nextRoad)

    @nextLane = nextRoad.lanes[laneNumber]
    throw Error 'can not pick next lane' if not @nextLane
    @fixed_positioning = false
    return @nextLane

  popNextLane: ->
    nextLane = @nextLane
    @nextLane = null
    @preferedLane = null
    return nextLane

  getPossibleTurns: ->
    intersection = @trajectory.nextIntersection
    currentLane = @trajectory.current.lane

    possibleRoads = intersection.roads.filter (x) -> x.target != currentLane.road.source

    possibleTurns = possibleRoads.map (o) -> currentLane.road.getTurnDirection(o)
      
    return possibleTurns

  chooseLaneNumber: (turnNumber, road) ->
    possibleTurns = @getPossibleTurns()#Important info: Rightmost lane is 0
    switch turnNumber
      when 0#If I want to turn left
        b = 1.0
        a = 7.0
        if( 1 not in possibleTurns and 2 not in possibleTurns) #I can only go left
          b = 1.0
          a = 1.0
        else if 2 not in possibleTurns#I can go left and straight
          a = 20.0
          b = 1.0
        else if 1 not in possibleTurns#I can go left and right
          a = 5.0
          b = 1.0
      when 1#If I want to go straight
        b = 10.0
        a = 10.0
        if( 0 not in possibleTurns and 2 not in possibleTurns)#I can only go straight
          b = 1.0
          a = 1.0
        else if 2 not in possibleTurns#I can go straight and left
          a = 1.0
          b = 7.0
        else if 0 not in possibleTurns#I can go straight and right
          a = 7.0
          b = 1.0
      when 2 #If I want to go right
        b = 7.0
        a = 1.0
        if( 0 not in possibleTurns and 1 not in possibleTurns)#I can only go right
          b = 1.0
          a = 1.0
        else if 1 not in possibleTurns#I can go right and left
          a = 1.0
          b = 5.0
        else if 0 not in possibleTurns#I can go right and straight.
          a = 1.0
          b = 20.0
    #Beta-Binomial(a,b,k)
    laneNumber = binomial(road.lanesNumber-1, beta(a, b))
    while road.lanes[laneNumber].isClosed
      laneNumber = binomial(road.lanesNumber-1, beta(a, b))
    return laneNumber


module.exports = Car
