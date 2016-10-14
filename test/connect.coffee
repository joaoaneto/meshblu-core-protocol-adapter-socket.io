_ = require 'lodash'
meshblu = require 'meshblu'
async = require 'async'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
JobManager = require 'meshblu-core-job-manager'
Server = require '../src/server'

class Connect
  constructor: ->
    @client = new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
    @jobManager = new JobManager
      client: @client
      timeoutSeconds: 1
      jobLogSampleRate: 0

  connect: (callback) =>
    async.series [
      @startServer
      @createConnection
      @authenticateConnection
    ], (error) =>
      return callback error if error?
      @connection.on 'ready', =>
        process.nextTick =>
          callback null,
            sut: @sut
            connection: @connection
            device: {uuid: 'masseuse', token: 'assassin'}
            jobManager: new JobManager
              client: new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
              timeoutSeconds: 1
              jobLogSampleRate: 0
    return # avoid returning async

  shutItDown: (callback) =>
    @client.del 'request:queue', =>
      @connection.close =>
        @sut.stop callback
    return # promises

  startServer: (callback) =>
    @sut = new Server
      port: 0xcafe
      jobTimeoutSeconds: 1
      jobLogRedisUri: 'redis://localhost'
      redisUri: 'redis://localhost'
      jobLogQueue: 'junk'
      namespace: 'ns'
      jobLogSampleRate: 0
      maxConnections: 10

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
    @jobManager.getRequest ['request'], (error, @request) =>
      return callback error if error?

      response =
        metadata:
          responseId: @request.metadata.responseId
          code: 204

      @jobManager.createResponse 'response', response, callback

module.exports = Connect
