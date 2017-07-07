Bundler.require
require 'yaml'

$config = YAML.load_file 'config.yml'

threads = []

$config['ports'].each do |port|
  threads << Thread.new do
    puts "Listening on port #{port['port']}"
    udp = UDPSocket.new
    udp.bind("", port['port'])
    while true do
      text, host = udp.recvfrom(1024)
      puts "#{Time.now.to_s} #{port['port']} #{port['channel']}: #{text}"
      
      channel = port['channel']

      cleantext = text.gsub(/\x03\d{1,2}/,'').gsub(/\x03/,'')
      
      # TODO: move channel names to config file
      # Route wiki edits to different channels based on the page or uploaded file name
      if channel == '#indieweb-dev'
        filename = nil
        if m = cleantext.match(/uploaded "\[\[File:([^\]]+)\]\]"/i)
          filename = m[1]
        elsif m = cleantext.match(/^\[\[([^\]]+)\]\]/)
          filename = m[1]
        end
        
        if filename
          if filename.match(/^[0-9]{4}/) or filename.match(/^events[^\]]*/) or filename.match(/Template:[^\]]*/i)
            channel = '#indieweb-meta'
          elsif filename.match(/wordpress[^\]]*/i)
            channel = '#indieweb-wordpress'
          end
        end
      end
      
      # Reformat upload messages to include a URL
      if m = cleantext.match(/uploaded "\[\[(File:[^\]]+)\]\]"/i)
        text = text.strip+" "+port['wiki']+m[1]
      end
      
      result = HTTParty.post "#{port['url']}/message", {
        body: {
          channel: channel,
          content: text
        },
        headers: {
          "Authorization" => "Bearer #{$config['token']}"
        }
      }
    end
  end
end

puts "Ready"
threads.map &:join
