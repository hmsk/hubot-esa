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
#   HUBOT_ESA_TEAM_NAME
#   HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
#   HUBOT_ESA_WEBHOOK_ENDPOINT
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

handleWebhook = (payload) ->
  # https://docs.esa.io/posts/37
  switch payload.kind
    when 'post_create'
      return "#{payload.user.screen_name} created a new post: #{if payload.post.wip then '(WIP) ' else ''}#{payload.post.name}\n>#{payload.post.message}\n#{payload.post.url}"
    when 'post_update'
      return "#{payload.user.screen_name} updated the post: #{if payload.post.wip then '(WIP) ' else ''}#{payload.post.name}\n>#{payload.post.message}\n#{payload.post.url}"
    when 'post_archive'
      return "#{payload.user.screen_name} archived the post: #{payload.post.name}\n#{payload.post.url}"
    when 'comment_create'
      return "#{payload.user.screen_name} posted a comment to #{payload.post.name}\n>#{payload.comment.body_md.replace("\n",'')}\n#{payload.post.url}"
    when 'member_join'
      return "New member joined: #{payload.name}(#{payload.screen_name})"
    else
      return "Unknown Webhook received"

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
    robot.messageRoom options.room, handleWebhook(req.body or {})
    res.writeHead(204)
    res.end()

  robot.respond /esa stats/, (res) ->
    esa.getRequest("/stats", (stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\b/, (res) ->
    unless res.match[1] == options.team then return
    esa.getRequest("/posts/#{res.match[2]}", (post) ->
      res.send "esa: #{post.full_name}"
    )
  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\#comment-(\d+)/, (res) ->
    unless res.match[1] == options.team then return
    esa.getRequest("/comments/#{res.match[3]}", (comment) ->
      res.send "#{comment.body_md}"
    )
