_                       = require 'lodash'
http                    = require 'http'
SocketIO                = require 'socket.io'
SocketIOHandler         = require './socket-io-handler'
RedisPooledJobManager   = require 'meshblu-core-redis-pooled-job-manager'
redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @maxConnections
      @redisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
    } = options
    throw new Error('need a jobLogQueue') unless @jobLogQueue?
    throw new Error('need a jobLogSampleRate') unless @jobLogSampleRate?

  address: =>
    @server.address()

  run: (callback) =>
    @server = http.createServer()

    @jobManager = new RedisPooledJobManager {
      jobLogIndexPrefix: 'metric:meshblu-core-protocol-adapter-socket-io'
      jobLogType: 'meshblu-core-protocol-adapter-socket-io:request'
      minConnections: 5
      idleTimeoutMillis: 5*60*1000
      @jobTimeoutSeconds
      @jobLogQueue
      @jobLogRedisUri
      @jobLogSampleRate
      @maxConnections
      @redisUri
      @namespace
    }

    uuidAliasClient = new RedisNS 'uuid-alias', redis.createClient(@redisUri, dropBufferSupport: true)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: @aliasServerUri

    @messengerManagerFactory = new MessengerManagerFactory {uuidAliasResolver, @namespace, redisUri: @firehoseRedisUri}

    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler {socket, @jobManager, @messengerManagerFactory}
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
