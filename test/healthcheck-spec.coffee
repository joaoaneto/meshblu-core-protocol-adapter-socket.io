_       = require 'lodash'
Server  = require '../src/server'
uuid    = require 'uuid'
url     = require 'url'
request = require 'request'
redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'

describe 'healthcheck', ->
  beforeEach (done) ->
    @redisId = uuid.v1()

    @sut = new Server
      port: 0xcafe
      jobTimeoutSeconds: 1
      meshbluConfig:
        server: 'localhost'
        port:   0xbabe
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      jobLogQueue: 'jobz'
      jobLogSampleRate: 0

    @sut.run done

  afterEach (done) ->
    @sut.stop done

  describe 'when a healthcheck is performed', ->
    beforeEach (done) ->
      uri = url.format
        hostname: 'localhost'
        port: 0xcafe
        protocol: 'http'
        pathname: 'healthcheck'

      request.get uri, (error, @response, @body) =>
        done error

    it 'should respond with a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should respond online: true', ->
      expect(JSON.parse @body).to.deep.equal online: true

  describe 'when any other request is performed', ->
    beforeEach (done) ->
      uri = url.format
        hostname: 'localhost'
        port: 0xcafe
        protocol: 'http'
        pathname: 'injury'

      request.get uri, (error, @response, @body) =>
        done error

    it 'should respond with a 404', ->
      expect(@response.statusCode).to.equal 404
