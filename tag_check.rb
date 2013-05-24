require 'mp3info'
require 'open-uri'
require 'json'
require 'colorize'

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
  method = "?method=artist.gettoptracks&artist=#{artist_param}&api_key=#{APIKEY}&format=json&limit=500"
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
      track_title = info.tag.title || File.basename(f)
      similar = top_tracks.select do |top_track|
        levenschtein(track_title, top_track[:name]) < track_title.length / 3 \
          or track_title.include? top_track[:name][0...track_title.length]
      end
      similar.sort_by!{|s| levenschtein(track_title, s[:name]) }
      if similar.length > 0
        if similar[0][:name].eql? info.tag.title and similar.length == 1
          puts "Already matches top!".green
        else
          puts "Similar: "
          similar.each_with_index do |sim, i|
            puts "#{i+1} #{sim[:name]} (#{levenschtein(track_title, sim[:name])}) (#{sim[:listeners]})"
          end
          print 'Replace with ? (#/[n]/e) '.red
          choice = gets.chomp
          if choice.eql? 'e'
            puts 'Replace with? '
            new_name = gets.chomp
            puts "Changing to: #{new_name}".blue
            info.tag.title = new_name
          elsif choice.eql? 'y' or (1..similar.length).include? choice.to_i
            puts "Changing to: #{similar[choice.to_i - 1][:name]}".blue
            info.tag.title = similar[choice.to_i - 1][:name]
          end
        end
      end
    end
  end
end
