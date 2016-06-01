class RevokeTokenByQueryHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'RevokeTokenByQuery'
        toUuid: data.uuid ? @auth.uuid
        fromUuid: @auth.uuid
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback null if error?
      return callback null unless response?
      return callback JSON.parse(response.rawData) if response.rawData?
      callback null

module.exports = RevokeTokenByQueryHandler
