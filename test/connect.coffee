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
    @client = new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
    @queueClient = new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
    @jobManager = new JobManagerResponder {
      @client
      @queueClient
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      @responseQueueName
    }

  connect: (callback) =>
    @createConnection (error) =>
      return callback error if error?
      @connection.on 'ready', =>
        client = new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
        queueClient = new RedisNS 'ns', new Redis 'localhost', dropBufferSupport: true
        callback null,
          sut: @sut
          connection: @connection
          device: {uuid: 'masseuse', token: 'assassin'}
          jobManager: new JobManagerResponder {
            client
            queueClient
            jobTimeoutSeconds: 10
            queueTimeoutSeconds: 10
            jobLogSampleRate: 0
            @requestQueueName
            @responseQueueName
          }

    async.series [
      @startServer
      @authenticateConnection
    ], (error) =>
      return callback error if error?

    return # avoid returning async

  shutItDown: (callback) =>
    @client.del 'request:queue', =>
      @connection.close =>
        @sut.stop callback
    return # promises

  startServer: (callback) =>
    @sut = new Server {
      port: 0xcafe
      jobTimeoutSeconds: 1
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      cacheRedisUri: 'redis://localhost'
      firehoseRedisUri: 'redis://localhost'
      jobLogQueue: 'junk'
      namespace: 'ns'
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
    , callback

module.exports = Connect
