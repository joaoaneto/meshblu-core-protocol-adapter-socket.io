class RevokeSessionTokenHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'RevokeSessionToken'
        toUuid: data.uuid
        fromUuid: @auth.uuid
        auth: @auth
      data: data

    @jobManager.do request, (error, response) =>
      return callback null if error?
      return callback null unless response?
      return callback JSON.parse(response.rawData) if response.rawData?
      callback null

module.exports = RevokeSessionTokenHandler
