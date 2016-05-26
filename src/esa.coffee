# Descriptipn
#   Hubot script handle webhook and API of https://esa.io
#
# Dependencies:
#   None
#
# Commands:
#    hubot esa stats - Retrieve stats of your team on esa
#
# Configuration:
#   HUBOT_ESA_ACCESS_TOKEN
#   HUBOT_ESA_TEAM
#   HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
#   HUBOT_ESA_WEBHOOK_ENDPOINT
#   HUBOT_ESA_WEBHOOK_JUST_EMIT
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

handleEsaWebhook = (payload) ->
  # https://docs.esa.io/posts/37
  if payload.kind is undefined || payload.team is undefined || payload.user is undefined
    return {
      kind: null
      data: null
    }
  parsed =
    kind: payload.kind
    data:
      team: payload.team.name
      user: payload.user
      post: null
      comment: null

  switch parsed.kind
    when 'post_create', 'post_update', 'post_archive'
      parsed.data.post = payload.post
    when 'comment_create'
      parsed.data.post = payload.post
      parsed.data.comment = payload.comment
  return parsed

class EsaClientRobot
  constructor: (@robot, @team, @access_token) ->

  baseUrl = ()->
    "https://api.esa.io/v1/teams/#{@team}"

  getRequest: (path, callback) ->
    @robot.http("#{baseUrl.call @}#{path}").query({access_token: @access_token}).get() (error, response, body) ->
      if response.statusCode is 200
        callback(JSON.parse(body))
      else
        @robot.logger.warning "esa API GET request failed: #{error}"

module.exports = (robot) ->
  options =
    team: process.env.HUBOT_ESA_TEAM
    token: process.env.HUBOT_ESA_ACCESS_TOKEN
    room: process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
    endpoint: process.env.HUBOT_ESA_WEBHOOK_ENDPOINT || '/hubot/esa'
    just_emit: process.env.HUBOT_ESA_WEBHOOK_JUST_EMIT == 'true'

  return robot.logger.error "Missing configuration: HUBOT_ESA_TEAM" unless options.team?
  return robot.logger.error "Missing configuration: HUBOT_ESA_ACCESS_TOKEN" unless options.token?
  return robot.logger.error "Missing configuration: HUBOT_ESA_WEBHOOK_DEFAULT_ROOM" unless options.room?

  esa = new EsaClientRobot(robot, options.team, options.token)
  robot.router.post options.endpoint, (req, res) ->
    # https://docs.esa.io/posts/37#3-4-0
    unless req.headers['user-agent'] == 'esa-Hookshot/v1'
      robot.logger.warning "Requested unknown user agent: #{req.headers['user-agent']}"
      res.writeHead(403)
      res.end()
      return
    parsed = handleEsaWebhook(req.body or {})
    robot.emit 'esa.webhook', parsed.kind, parsed.data
    res.writeHead(204)
    res.end()

  robot.respond /esa stats/, (res) ->
    esa.getRequest("/stats", (stats) ->
      robot.emit 'esa.hear.stats', res, stats
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)(?!(\#comment-\d+))\b/, (res) ->
    unless res.match[1] == options.team then return
    esa.getRequest("/posts/#{res.match[2]}", (post) ->
      robot.emit 'esa.hear.post', res, post
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\#comment-(\d+)\b/, (res) ->
    unless res.match[1] == options.team then return
    esa.getRequest("/comments/#{res.match[3]}", (comment) ->
      robot.emit 'esa.hear.comment', res, comment
    )

  unless options.just_emit
    robot.on 'esa.webhook', (kind, data) ->
      robot.messageRoom options.room, switch kind
        when 'post_create'
           "#{data.user.screen_name} created a new post: #{if data.post.wip then '(WIP) ' else ''}#{data.post.name}\n>#{data.post.message}\n#{data.post.url}"
        when 'post_update'
           "#{data.user.screen_name} updated the post: #{if data.post.wip then '(WIP) ' else ''}#{data.post.name}\n>#{data.post.message}\n#{data.post.url}"
        when 'post_archive'
           "#{data.user.screen_name} archived the post: #{data.post.name}\n#{data.post.url}"
        when 'comment_create'
           "#{data.user.screen_name} posted a comment to #{data.post.name}\n>#{data.comment.body_md.replace("\n",'')}\n#{data.post.url}"
        when 'member_join'
           "New member joined: #{data.user.name}(#{data.user.screen_name})"
        else
          robot.logger.warning "Unknown kind of Webhook received: #{kind}"
          "Unknown kind of Webhook received #{kind}"

    robot.on 'esa.hear.stats', (res, stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"

    robot.on 'esa.hear.post', (res, post) ->
      res.send "esa: #{post.full_name}"

    robot.on 'esa.hear.comment', (res, comment) ->
      res.send "esa: #{comment.body_md}"
