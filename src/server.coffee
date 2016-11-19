_                       = require 'lodash'
http                    = require 'http'
SocketIO                = require 'socket.io'
SocketIOHandler         = require './socket-io-handler'
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'
RateLimitChecker        = require 'meshblu-core-rate-limit-checker'
JobLogger               = require 'job-logger'
{ JobManagerRequester } = require 'meshblu-core-job-manager'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @maxConnections
      @redisUri
      @cacheRedisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
    } = options
    throw new Error('need a jobLogQueue') unless @jobLogQueue?
    throw new Error('need a jobLogSampleRate') unless @jobLogSampleRate?
    throw new Error('need a cacheRedisUri') unless @cacheRedisUri?
    throw new Error('need a firehoseRedisUri') unless @firehoseRedisUri?
    throw new Error('need a redisUri') unless @redisUri?
    throw new Error('need a requestQueueName') unless @requestQueueName?
    throw new Error('need a responseQueueName') unless @responseQueueName?

  address: =>
    @server.address()

  run: (callback) =>
    @server = http.createServer()

    client = new RedisNS @namespace, new Redis @redisUri, dropBufferSupport: true
    queueClient = new RedisNS @namespace, new Redis @redisUri, dropBufferSupport: true

    jobLogger = new JobLogger
      client: new Redis @jobLogRedisUri, dropBufferSupport: true
      indexPrefix: 'metric:meshblu-core-protocol-adapter-socket-io'
      type: 'meshblu-core-protocol-adapter-socket-io:request'
      jobLogQueue: @jobLogQueue

    @jobManager = new JobManagerRequester {
      client
      queueClient
      @jobTimeoutSeconds
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
      queueTimeoutSeconds: @jobTimeoutSeconds
    }

    @jobManager._do = @jobManager.do
    @jobManager.do = (request, callback) =>
      @jobManager._do request, (error, response) =>
        jobLogger.log { error, request, response }, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response

    queueClient.on 'ready', =>
      @jobManager.startProcessing()

    cacheClient = new Redis @cacheRedisUri, dropBufferSupport: true

    uuidAliasClient = new RedisNS 'uuid-alias', cacheClient
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: @aliasServerUri

    rateLimitCheckerClient = new RedisNS 'meshblu-count', cacheClient
    @rateLimitChecker = new RateLimitChecker client: rateLimitCheckerClient

    @messengerManagerFactory = new MessengerManagerFactory {
      redisUri: @firehoseRedisUri
      uuidAliasResolver
      @namespace
    }

    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @jobManager?.stopProcessing()
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler {
      socket
      @jobManager
      @messengerManagerFactory
      @rateLimitChecker
    }
    socketIOHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

module.exports = Server
