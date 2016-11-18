class IdentityAuthenticateHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback=->) =>
    {uuid, token} = data
    return callback null, metadata: {code: 204} unless uuid? && token?

    request =
      metadata:
        jobType: 'Authenticate'
        auth:
          uuid: uuid
          token: token

    @jobManager.do request, (error, response) =>
      return callback error if error?
      callback null, response

module.exports = IdentityAuthenticateHandler
