http = require 'http'
SocketIO = require 'socket.io'
SocketIOHandler = require './socket-io-handler'

class Server
  constructor: (options) ->
    {@client, @timeoutSeconds, @port, @meshbluConfig} = options

  address: =>
    @server.address()

  start: (callback) =>
    @server = http.createServer()
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler
      socket: socket
      client: @client
      timeoutSeconds: @timeoutSeconds
      meshbluConfig: @meshbluConfig

    socketIOHandler.initialize()

module.exports = Server
