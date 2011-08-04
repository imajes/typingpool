#!/usr/bin/env ruby

require 'erb'
require 'audibleturk'

#Name of form field in Mechanical Turk assignment form
# containing URL to audio file
url_at_form_field = ARGV[0] || 'audibleturk_url'

home = "#{Dir.home}/Documents/Software/dist/ruby/audibleturk"

puts "Collecting results from Amazon..."
results = Audibleturk::Remote::Result.all_approved(:url_at => url_at_form_field)

puts "Sorting results..."
available_folders = results.collect{|result| result.transcription.title }.uniq.select{|title| Audibleturk::Folder.named(title)}

unless available_folders.empty?
  template = {
    'html' => IO.read("#{home}/www/transcript.html.erb"),
    'css' => IO.read("#{home}/www/transcript.css.erb")
  }
end
available_folders.each do |folder|
  shortname = folder
  folder = Audibleturk::Folder.named(folder)
  filename = {
    'done' => 'transcript.html',
    'working' => 'transcript_in_progress.html'
  }
  next if File.exists?("#{folder.path}/#{filename['done']}")
  css = ERB.new(template['css'], nil, '<>').result(binding())
  File.open("#{folder.path}/etc/transcript.css", 'w') do |out|
    out << css
  end
  transcription = Audibleturk::Transcription.new(shortname, results.select{|result| result.transcription.title == shortname}.collect{|result| result.transcription})
  transcription.each{|chunk| chunk.url = "audio/#{chunk.filename_local}" }
  transcription.subtitle = folder.subtitle
  File.delete("#{folder.path}/#{filename['working']}") if File.exists?("#{folder.path}/#{filename['working']}")
  is_done = (transcription.to_a.length == folder.audio_chunks)
  out_file = is_done ? filename['done'] : filename['working']
  html = ERB.new(template['html'], nil, '<>').result(binding())
  File.open("#{folder.path}/#{out_file}", 'w') do |out|
    out << html
  end
  puts "Wrote #{out_file} to folder #{shortname}."
end

