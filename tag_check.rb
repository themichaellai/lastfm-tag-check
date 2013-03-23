require 'mp3info'
require 'open-uri'
require 'json'

APIKEY = ""
APIROOT = "http://ws.audioscrobbler.com/2.0/"

$memo = {}

def levenschtein(s, t)
  key = s + t
  return $memo[key] if $memo.has_key? key

  return t.length if s.length == 0
  return s.length if t.length == 0
  cost = s[s.length-1] == t[t.length-1] ? 0 : 1
  dist = [
      levenschtein(s[0...(s.length-1)], t) + 1,
      levenschtein(s, t[0...(t.length-1)]) + 1,
      levenschtein(s[0...(s.length-1)], t[0...(t.length-1)]) + cost
    ].min
  $memo[key] = dist
  dist
end

def get_top_tracks(artist)
  artist_param = artist.gsub(/ /, '+')
  method = "?method=artist.gettoptracks&artist=#{artist_param}&api_key=#{APIKEY}&format=json&limit=200"
  data = JSON.parse open(APIROOT + method).read
  data['toptracks']['track'].map do |track|
    {
      name: track['name'],
      listeners: track['listeners']
    }
  end
end

if __FILE__ == $0
  artist_tracks = {}
  Dir.glob(Dir.pwd + '/**/*.mp3') do |f|
    Mp3Info.open(f) do |info|
      puts "- #{info.tag.title || File.basename(f)}"
      unless artist_tracks.has_key? info.tag.artist
        puts "Getting tracks for: #{info.tag.artist}"
        artist_tracks[info.tag.artist] = get_top_tracks info.tag.artist
        puts "Got #{artist_tracks[info.tag.artist].length} tracks"
      end
      top_tracks = artist_tracks[info.tag.artist]
      similar = top_tracks.select do |top_track|
        track_title = info.tag.title || File.basename(f)
        levenschtein(track_title, top_track[:name]) < track_title.length / 3
      end
      similar.sort_by!{|s| levenschtein(info.tag.title, s[:name]) }
      if similar.length > 0
        unless similar[0][:name].eql? info.tag.title
          puts "Similar: "
          similar.each { |sim| puts "- #{sim[:name]} (#{levenschtein(info.tag.title, sim[:name])})" }
          print 'Replace with first? (y/[n]) '
          if gets.chomp.eql? 'y'
            puts "Changing to: #{similar[0][:name]}"
            info.tag.title = similar[0][:name]
          end
        end
      end
    end
  end
end
