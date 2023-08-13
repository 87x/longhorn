local spawn = require('coro-spawn')
local split = require('coro-split')
local parse = require('url').parse
local discordia = require('discordia')
local json = require('json')
local http = require('http')

local client = discordia.Client()
local connection
local msg = ''
local channel
local guild
local playingURL = ''
local playingTrack = 0

connections={}

if not args[2] then
  print("Please specify a token.")
  os.exit()
end

print(client.voice)

print(args[2])

local function splitstr(inputstr, sep)
  if not sep then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function getStream(url)

  local child = spawn('yt-dlp', {
    args = {"--max-downloads","1","--print","urls","--no-audio-multistreams","--no-video-multistreams","--default-search","ytsearch15:search",url},
    stdio = {nil, true, true}
  })

  local stream
  local streams
  local function readstdout()
    local stdout = child.stdout
    for chunk in stdout.read do
      local mime = parse(chunk, true).query.mime
      print("mime",mime)
      print("chunk",chunk)
      if mime then
        if type(mime)=="table" then
          for i,v in pairs(mime) do
            print("mime DATA",v)
            if v:find('audio') then
              streams=splitstr(chunk)
              stream=streams[i]
            end
          end
        elseif type(mime)=="string" and mime:find('audio') then
          streams=splitstr(chunk)
          stream="multiple" -- HACK
        end
      end
    end
    return pcall(stdout.handle.close, stdout.handle)
  end

  local function readstderr()
    local stderr = child.stderr
    for chunk in stderr.read do
      print(chunk)
    end
    return pcall(stderr.handle.close, stderr.handle)
  end

  split(readstdout, readstderr, child.waitExit)

  return stream and stream:gsub('%c', ''),streams
end

--[[local function getPlaylistStream(url, number)
  local child = spawn('yt-dlp', {
    args = {'--print urls', '--playlist-items', number, url},
    stdio = {nil, true, true}
  })

  local stream
  local function readstdout()
    local stdout = child.stdout
    for chunk in stdout.read do
      local mime = parse(chunk, true).query.mime
      print("mime",mime)
      if mime then
        for i,v in pairs(mime) do
          print("mime DATA",v)
          if v:find('audio') then
            stream=chunk
          end
        end
      end
    end
    return pcall(stdout.handle.close, stdout.handle)
  end

  local function readstderr()
    local stderr = child.stderr
    for chunk in stderr.read do
      print(chunk)
    end
    return pcall(stderr.handle.close, stderr.handle)
  end

  split(readstdout, readstderr, child.waitExit)

  return stream and stream:gsub('%c', '')
end]] -- deprecated

local function len(tbl)
  local count = 0
  for k,v in pairs(tbl) do
    count = count + 1
  end
  return count
end

--[[local streamPlaylist = coroutine.wrap(function(url, beginWith)
  local child = spawn('yt-dlp', {
    args = {'-J', url},
  })
  stdio = {nil, true, true}
  local playlist = json.decode(child.stdout:read())
  connection = channel:join()
  if connection then
    print('Connected')
    for playingTrack = beginWith or 1, len(playlist.entries) do
      local stream = getPlaylistStream(url, playingTrack)
      print('Playing track '..playingTrack..' of '..len(playlist.entries))
      connection:playFFmpeg(stream)
    end
  end
end)]] -- deprecated

--client.voice:loadOpus('libopus-x86')
--client.voice:loadSodium('libsodium-x86')

client:on('ready', function()
  print('Logged in as ' .. client.user.username)
  channel = client:getChannel('980533602590793778') -- channel ID goes here

end)

client:on('messageCreate', function(message)
  print(os.date('!%Y-%m-%d %H:%M:%S', message.createdAt).. ' <'.. message.author.name.. '> '.. message.content) --Screen output
  if message.author.id ~= client.user.id then --If not himself
    msg = message
    if string.find(msg.content, 'audio%.play ') then
      if message.member then
        channel = message.member.voiceChannel
        guild = message.guild
      end
      if channel then
        connections[guild] = channel:join() -- chances are this is bugged on lit discordia. get from github instead.
      end
      print(guild,"channel",channel)
      print(guild,"connection",connection)
      if connections[guild] then
        print(guild,'success!')
        playingURL = string.gsub(msg.content, 'audio%.play ', '')
        local stream,streams = getStream(playingURL) -- URL goes here
        if stream then
          print(guild,"stream",stream)
          print(guild,'playing!')
          if stream and stream~="multiple" then -- todo: make not shit
            connections[guild]:playFFmpeg(stream)
          elseif streams and stream=="multiple" then
            for i,stream in ipairs(streams) do
              if true then
                connections[guild]:playFFmpeg(stream)
              end
            end
          else
            print(guild,"no streams")
          end
        else
          print(guild,"no stream!")
        end
      end
    --[[elseif string.find(msg.content, 'audio%.playlist ') then
      playingURL = string.gsub(msg.content, 'audio%.playlist ', '')
      streamPlaylist(playingURL, 2)]] -- deprecated
    elseif msg.content == 'audio.pause' then
      guild = message.guild
      if connections[guild] then
        connections[guild]:pauseStream(playingURL)
      end
    elseif msg.content == 'audio.resume' then
      guild = message.guild
      if connections[guild] then
        connections[guild]:resumeStream()
      end
    elseif msg.content == 'audio.skip' then
      guild = message.guild
      print(guild,'skipping')
      if connections[guild] then
        connections[guild]:stopStream()
      end
    elseif msg.content == 'audio.leave' then
      guild = message.guild
      print(guild,'stopping')
      if connections[guild] then
        connections[guild]:close()
      end
    end
  end
end)

client:run("Bot "..args[2])
