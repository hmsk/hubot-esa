Helper = require('hubot-test-helper')
chai = require 'chai'
http = require 'http'
nock = require 'nock'
fs = require 'fs'
crypto = require 'crypto'

expect = chai.expect

helper = new Helper('../src/esa.coffee')
process.env.EXPRESS_PORT = 8039

describe 'esa', ->
  room = null
  esaDeliveryKeyOfBrain = 'esaWebhookDeliveries'

  lastMessageBody = ()->
    room.messages[room.messages.length - 1][1]

  beforeEach ->
    process.env.HUBOT_ESA_ACCESS_TOKEN = 'dummy'
    process.env.HUBOT_ESA_TEAM = 'ginger'
    process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM = 'general'
    process.env.HUBOT_ESA_WEBHOOK_ENDPOINT = '/hubot/ginger'
    process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN = 'purrs'
    process.env.HUBOT_ESA_JUST_EMIT = 'false'
    room = helper.createRoom()

  afterEach ->
    room.destroy()

  describe 'Response to chatroom', ->
    nockScope = null
    beforeEach ->
      nock.disableNetConnect()
      nockScope = nock('https://api.esa.io')

    afterEach ->
      nock.cleanAll()

    context 'someone requests stats', ->
      emitted = false
      emitted_stats = null
      beforeEach (done) ->
        room.robot.on 'esa.hear.stats', (res, stats) ->
          emitted = true
          emitted_stats = stats
        nockScope
          .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/stats")
          .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
          .replyWithFile(200, "#{__dirname}/fixtures/stats.json")
        room.user.say('gingy', '@hubot esa stats')
        setTimeout done, 200

      it 'responds stats', ->
        expect(lastMessageBody()).contain("Members: 20\nPosts: 1959\nComments: 2695\nStars: 3115\nDaily Active Users: 8\nWeekly Active Users: 14\nMonthly Active Users: 15")

      it 'emits esa.hear.stats event with args', ->
        expect(emitted).to.equal true
        expect(emitted_stats.members).to.equal 20

    describe 'post', ->
      context 'in own team', ->
        emitted = false
        emitted_post = null
        beforeEach ->
          room.robot.on 'esa.hear.post', (res, post) ->
            emitted = true
            emitted_post = post
          nockScope
            .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/posts/1390")
            .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
            .replyWithFile(200, "#{__dirname}/fixtures/post.json")

        context 'someone says post url', ->
          beforeEach (done) ->
            room.user.say('gingy', 'https://ginger.esa.io/posts/1390')
            setTimeout done, 200

          it 'send message about post', ->
            expect(lastMessageBody()).contain('日報/2015/05/09/hi! #api #dev\nStars: 1, Watchers: 1, Comments: 1, Tasks: 1/1')

          it 'emits esa.hear.post event with args', ->
            expect(emitted).to.equal true
            expect(emitted_post.name).to.equal 'hi!'

        context 'someone says post url wtih anchor', ->
          beforeEach (done) ->
            room.user.say('gingy', 'https://ginger.esa.io/posts/1390#1-1-1')
            setTimeout done, 200

          it 'send message about post', ->
            expect(lastMessageBody()).contain('日報/2015/05/09/hi! #api #dev\nStars: 1, Watchers: 1, Comments: 1, Tasks: 1/1')

      context 'in other team, someone says post url', ->
        beforeEach (done) ->
          room.user.say('gingy', 'https://zachary.esa.io/posts/1390')
          setTimeout done, 200

        it 'nothing to say', ->
          expect(room.messages).to.eql [
            ['gingy', 'https://zachary.esa.io/posts/1390']
          ]

    describe 'comment', ->
      context 'in own team', ->
        emitted = false
        emitted_comment = null
        emitted_post = null
        beforeEach (done) ->
          room.robot.on 'esa.hear.comment', (res, comment, post) ->
            emitted = true
            emitted_comment = comment
            emitted_post = post
          nockScope
            .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/comments/2121")
            .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
            .replyWithFile(200, "#{__dirname}/fixtures/comment.json")
          nockScope
            .get("/v1/teams/#{process.env.HUBOT_ESA_TEAM}/posts/1390")
            .query(access_token: process.env.HUBOT_ESA_ACCESS_TOKEN)
            .replyWithFile(200, "#{__dirname}/fixtures/post.json")
          room.user.say('gingy', 'https://ginger.esa.io/posts/1390#comment-2121')
          setTimeout done, 200

        it 'send message about comment', ->
          expect(lastMessageBody()).contain '読みたい'
          expect(lastMessageBody()).contain 'hi!'

        it 'emits esa.hear.comment event with args', ->
          expect(emitted).to.equal true
          expect(emitted_comment.body_md).to.equal '読みたい'
          expect(emitted_post.name).to.equal 'hi!'

      context 'in other team, someone says comment url', ->
        beforeEach (done) ->
          room.user.say('gingy', 'https://zachary.esa.io/posts/1390#comment-2121')
          setTimeout done, 200

        it 'nothing to say', ->
          expect(room.messages).to.eql [
            ['gingy', 'https://zachary.esa.io/posts/1390#comment-2121']
          ]

  describe 'Receive webhook', ->
    executeWebhook = (fixture_name, callback, opt_callback) ->
      body = JSON.stringify(JSON.parse(fs.readFileSync("#{__dirname}/fixtures/#{fixture_name}.json", 'utf-8')))
      http_opt =
        hostname: 'localhost'
        port: 8039
        path: '/hubot/ginger'
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
          'User-Agent': 'esa-Hookshot/v1'
          'X-Esa-Delivery': '1234'
          'X-Esa-Signature': generateSignature(body)
      unless opt_callback is undefined
        http_opt = opt_callback(http_opt)

      req = http.request http_opt, (response) => callback(response)
      req.write(body)
      req.end()

    # https://docs.esa.io/posts/37#3-4-0
    generateSignature = (body)->
      'sha256=' + crypto.createHmac('sha256', process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN).update(body, 'utf-8').digest('hex')

    http_opt = null
    emitted = null
    emitted_kind = null
    emitted_data = null

    beforeEach ->
      room.robot.brain.set esaDeliveryKeyOfBrain, undefined
      emitted = false
      emitted_data = null
      emitted_kind = null
      room.robot.on 'esa.webhook', (kind, data) ->
        emitted = true
        emitted_kind = kind
        emitted_data = data
      nock.enableNetConnect()

    afterEach ->
      nock.disableNetConnect()

    describe 'as valid request', ->
      context 'with unknown formated body', ->
        beforeEach (done) ->
          executeWebhook 'webhook_unknown', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal null
          expect(emitted_data).to.equal null

        it 'sends message', ->
          expect(lastMessageBody()).contain("Unknown kind of Webhook received null")

      context 'with post_create event data', ->
        beforeEach (done) ->
          executeWebhook 'webhook_post_create', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event with args', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal 'post_create'
          expect(emitted_data.team).to.equal 'esa'
          expect(emitted_data.user.screen_name).to.equal 'fukayatsu'
          expect(emitted_data.post.name).to.equal 'たいとる'
          expect(emitted_data.comment).to.equal null

        it 'sends message', ->
          expect(lastMessageBody()).contain("fukayatsu created a new post: たいとる\n>Create post.\nhttps://example.esa.io/posts/1253")

      context 'with post_update event data', ->
        beforeEach (done) ->
          executeWebhook 'webhook_post_update', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event with args', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal 'post_update'
          expect(emitted_data.team).to.equal 'esa'
          expect(emitted_data.user.screen_name).to.equal 'fukayatsu'
          expect(emitted_data.post.name).to.equal 'たいとる'
          expect(emitted_data.comment).to.equal null

        it 'sends message', ->
          expect(lastMessageBody()).contain("fukayatsu updated the post: たいとる\n>Update post.\nhttps://example.esa.io/posts/1253")

      context 'with post_archive event data', ->
        beforeEach (done) ->
          executeWebhook 'webhook_post_archive', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event with args', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal 'post_archive'
          expect(emitted_data.team).to.equal 'esa'
          expect(emitted_data.user.screen_name).to.equal 'fukayatsu'
          expect(emitted_data.post.name).to.equal 'Archived/たいとる'
          expect(emitted_data.comment).to.equal null

        it 'sends message', ->
          expect(lastMessageBody()).contain("fukayatsu archived the post: Archived/たいとる\nhttps://example.esa.io/posts/1253")

      context 'with comment_create event data', ->
        beforeEach (done) ->
          executeWebhook 'webhook_comment_create', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event with args', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal 'comment_create'
          expect(emitted_data.team).to.equal 'esa'
          expect(emitted_data.user.screen_name).to.equal 'fukayatsu'
          expect(emitted_data.post.name).to.equal 'Archived/たいとる'
          expect(emitted_data.comment.body_md).to.equal 'こめんと'

        it 'sends message', ->
          expect(lastMessageBody()).contain("fukayatsu posted a comment to Archived/たいとる\n>こめんと\nhttps://example.esa.io/posts/1253#comment-6385")

      context 'with member_join event data', ->
        beforeEach (done) ->
          executeWebhook 'webhook_member_join', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'emits esa.webhook event with args', ->
          expect(emitted).to.equal true
          expect(emitted_kind).to.equal 'member_join'
          expect(emitted_data.team).to.equal 'esa'
          expect(emitted_data.user.screen_name).to.equal 'fukayatsu'
          expect(emitted_data.post).to.equal null
          expect(emitted_data.comment).to.equal null

        it 'sends message', ->
          expect(lastMessageBody()).contain("New member joined: Atsuo Fukaya(fukayatsu)")

      context 'with recently and duplicated hooked data', ->
        beforeEach (done) ->
          room.robot.brain.set esaDeliveryKeyOfBrain, { '1234': new Date().getTime() - 3600 * 1000 * 10 }
          executeWebhook 'webhook_member_join', (response) =>
            @res = response
            done()

        it 'responds with status 409', ->
          expect(@res.statusCode).to.equal 409

        it 'not emit esa.webhook event', ->
          expect(emitted).to.equal false

        it 'not sends message', ->
          expect(room.messages).to.be.empty

      context 'with duplicated but old hooked data', ->
        beforeEach (done) ->
          room.robot.brain.set esaDeliveryKeyOfBrain, { '1234': new Date().getTime() - 3600 * 1000 * 50 }
          executeWebhook 'webhook_member_join', (response) =>
            @res = response
            done()

        it 'responds with status 204', ->
          expect(@res.statusCode).to.equal 204

        it 'not emit esa.webhook event', ->
          expect(emitted).to.equal true

        it 'not sends message', ->
          expect(room.messages).to.not.be.empty

    describe 'as invalid request', ->
      context 'with unkown User-Agent', ->
        beforeEach (done) ->
          executeWebhook 'webhook_member_join', (response) =>
            @res = response
            done()
          , (http_opt) ->
            http_opt['headers']['User-Agent'] = 'gingypurrs'
            http_opt

        it 'responds with status 401', ->
          expect(@res.statusCode).to.equal 401

      context 'with invalid signature', ->
        beforeEach (done) ->
          executeWebhook 'webhook_member_join', (response) =>
            @res = response
            done()
          , (http_opt) ->
            http_opt['headers']['X-Esa-Signature'] = 'sha256-soinvalid'
            http_opt

        it 'responds with status 401', ->
          expect(@res.statusCode).to.equal 401
