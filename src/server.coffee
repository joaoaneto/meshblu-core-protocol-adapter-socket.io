_                 = require 'lodash'
http              = require 'http'
SocketIO          = require 'socket.io'
SocketIOHandler   = require './socket-io-handler'
JobLogger         = require 'job-logger'
PooledJobManager  = require 'meshblu-core-pooled-job-manager'
{Pool}            = require 'generic-pool'
redis             = require 'redis'
RedisNS           = require '@octoblu/redis-ns'
MessengerFactory  = require './messenger-factory'
UuidAliasResolver = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @meshbluConfig, @aliasServerUri} = options
    {@connectionPoolMaxConnections, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue, @jobLogSampleRate} = options
    throw new Error('need a jobLogQueue') unless @jobLogQueue?
    throw new Error('need a jobLogSampleRate') unless @jobLogSampleRate?

  address: =>
    @server.address()

  run: (callback) =>
    @server = http.createServer()
    connectionPool = @_createConnectionPool()

    jobLogger = new JobLogger
      indexPrefix: 'metric:meshblu-server-socket.io-v1'
      type: 'meshblu-server-socket.io-v1:request'
      client: redis.createClient(@jobLogRedisUri)
      jobLogQueue: @jobLogQueue
      sampleRate: @jobLogSampleRate

    @jobManager = new PooledJobManager
      timeoutSeconds: @jobTimeoutSeconds
      pool: connectionPool
      jobLogger: jobLogger

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', redis.createClient(@redisUri)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    @messengerFactory = new MessengerFactory {uuidAliasResolver, @redisUri, @namespace}

    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler {socket, @jobManager, @meshbluConfig, @messengerFactory}
    socketIOHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

  _createConnectionPool: =>
    connectionPool = new Pool
      max: @connectionPoolMaxConnections
      min: 0
      returnToHead: true # sets connection pool to stack instead of queue behavior
      create: (callback) =>
        client = new RedisNS @namespace, redis.createClient(@redisUri)

        client.on 'end', ->
          client.hasError = new Error 'ended'

        client.on 'error', (error) ->
          client.hasError = error
          callback error if callback?

        client.once 'ready', ->
          callback null, client
          callback = null

      destroy: (client) => client.end true
      validate: (client) => !client.hasError?

    return connectionPool

module.exports = Server
