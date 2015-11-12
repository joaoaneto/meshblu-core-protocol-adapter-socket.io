http = require 'http'
SocketIO = require 'socket.io'

class UpstreamMeshbluServer
  constructor: (options) ->
    {@onConnection, @port} = options

  start: (callback) =>
    @server = http.createServer()
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

module.exports = UpstreamMeshbluServer
