_       = require 'lodash'
meshblu = require 'meshblu'
async   = require 'async'
Redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
Server  = require '../src/server'
UUID    = require 'uuid'
{ JobManagerResponder } = require 'meshblu-core-job-manager'

class Connect
  constructor: ->
    queueId = UUID.v4()
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @namespace = 'test:http'
    @redisUri = 'redis://localhost'
    @workerFunc = (@request, callback=_.noop) =>
      @jobManagerDo @request, callback

    @jobManager = new JobManagerResponder {
      @namespace
      @redisUri
      maxConnections: 1
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
      @workerFunc
    }
    @jobManager.do = (@jobManagerDo) =>
    @jobManager.wait = (@testCallback) =>

  connect: (callback) =>
    @jobManager.start (error) =>
      return callback error if error?
      @createConnection (error) =>
        return callback error if error?
        @connection.on 'ready', =>
          callback null, {
            sut: @sut
            connection: @connection
            device: {uuid: 'masseuse', token: 'assassin'}
            @jobManager
          }

    async.series [
      @startServer
      @authenticateConnection
    ], (error) =>
      return callback error if error?

    return # avoid returning async

  shutItDown: (callback) =>
    @jobManager.stop() # don't wait
    @connection.close =>
      @sut.stop callback

  startServer: (callback) =>
    @sut = new Server {
      port: 0xcafe
      jobTimeoutSeconds: 1
      jobLogRedisUri: @redisUri
      redisUri: @redisUri
      cacheRedisUri: @redisUri
      firehoseRedisUri: @redisUri
      jobLogQueue: 'junk'
      namespace: @namespace
      jobLogSampleRate: 0
      maxConnections: 10
      @requestQueueName
      @responseQueueName
    }

    @sut.run callback

  createConnection: (callback) =>
    @connection = meshblu.createConnection
      server: 'localhost'
      port: 0xcafe
      uuid: 'masseuse'
      token: 'assassin'
      options: transports: ['websocket']
      auto_set_online: false

    @connection.on 'notReady', (error) =>
      console.error error.stack
      throw error

    callback()

  authenticateConnection: (callback) =>
    @jobManager.do (request, next) =>
      response =
        metadata:
          responseId: request.metadata.responseId
          code: 204
      next null, response
      @jobManagerDo = (request, callback) =>
        @testCallback null, { request, callback } # WTF?!
    , callback

module.exports = Connect
