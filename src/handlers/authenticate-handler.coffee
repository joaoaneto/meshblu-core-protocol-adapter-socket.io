class AuthenticateHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (callback=->) =>
    return callback null, metadata: {code: 204} unless @auth.uuid? && @auth.token?

    request =
      metadata:
        jobType: 'Authenticate'
        auth: @auth

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error if error?
      callback null, response

module.exports = AuthenticateHandler
