_ = require 'lodash'
meshblu = require 'meshblu'
async = require 'async'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
JobManager = require 'meshblu-core-job-manager'
Server = require '../src/server'

class Connect
  constructor: ->
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
      timeoutSeconds: 1

  connect: (callback) =>
    async.series [
      @startServer
      @createConnection
      @authenticateConnection
    ], (error) =>
      return callback error if error?
      @connection.on 'ready', =>
        callback null,
          sut: @sut
          connection: @connection
          device: {uuid: 'masseuse', token: 'assassin'}
          jobManager: new JobManager
            client: new RedisNS 'ns', redis.createClient(dropBufferSupport: true)
            timeoutSeconds: 1

  shutItDown: (callback) =>
    @connection.close =>
      @sut.stop callback

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
