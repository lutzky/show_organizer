#!/usr/bin/ruby -w

require 'rubygems'
require 'english/style'
require 'pathname'
require 'pp'
require 'logger'
require 'yaml'

$LOG = Logger.new(STDOUT)

$LOG.level = Logger::WARN

VideoExtensions = [ ".avi", ".mpg", ".xvid", ".mkv" ]

class ShowPathname < Pathname
  def initialize path
    if path.is_a? Pathname
      super path.to_s
    else
      super path
    end
    @show_name = nil
  end

  def episode; figure_proper_name; @episode; end
  def season; figure_proper_name; @season; end
  def show_name; figure_proper_name; @show_name; end

  def formatted_filename
    figure_proper_name
    sprintf "%s S%02dE%02d%s", @show_name, @season, @episode, self.extname
  end

  private

  SeasonEpisodeRegex = [ /S(\d+)\.?E(\d+)/i, /(\d+)x(\d+)/ ]

  def figure_proper_name
    return unless @show_name.nil?

    basic_filename = self.basename(self.extname).to_s

    SeasonEpisodeRegex.each do |regex|
      match_obj = regex.match(basic_filename)
      if match_obj
        @season = match_obj[1].to_i
        @episode = match_obj[2].to_i
        @show_name = match_obj.pre_match
        clean_show_name
        return
      end
    end

    # Guess a unified season/episode number (304 => S03E04)
    match_obj = /\d{3,4}/.match(basic_filename)
    if match_obj
      unified_episode = match_obj[0].to_i
      @season = unified_episode / 100
      @episode = unified_episode % 100
      @show_name = match_obj.pre_match
      clean_show_name
      return
    end

    raise Exception.new("Could not figure out filename #{self.basename}")
  end

  def clean_show_name
    @show_name = @show_name.gsub(/[\.\-_]/," ").gsub(/[\s+]/," ").strip.\
      titlecase
  end

end

def is_video_file p
  p.file? and VideoExtensions.include?(p.extname.downcase)
end

class ShowOrganizer
  def initialize(inbox_path, library_path = inbox_path, unwatched_path = nil,
                 opts = {})
    @paths = {
      :inbox => Pathname.new(inbox_path),
      :library => Pathname.new(library_path),
      :unwatched => unwatched_path ? Pathname.new(unwatched_path) : nil,
    }

    @opts = opts
  end

  class WouldOverwriteException < Exception
    attr_reader :src, :dest

    def initialize(src, dest)
      super("Duplicate: #{src} would overwrite #{dest}")
      @src = src
      @dest = dest
    end
  end

  def organize_library
    duplicate_test_hash = {}

    @paths[:library].find do |p|
      if is_video_file p
        sp = ShowPathname.new(p)
        dest = @paths[:library] + sp.show_name + "Season #{sp.season}" + \
          sp.formatted_filename

        safely_move(sp, dest)

        episode_identifier = [sp.show_name, sp.season, sp.episode]

        duplicate_test_hash[episode_identifier] ||= []
        duplicate_test_hash[episode_identifier] << dest
      end
    end

    duplicate_test_hash.each do |k, v|
      if v.length > 1
        $LOG.warn { "These look like duplicates to me: " + \
          v.collect { |p| p.to_s }.join(", ")
        }
      end
    end
  end

  def safely_move(src, dest, opts = {})
    if src == dest
      return
    end

    if dest.exist?
      print "WOULD OVERWRITE"
      raise WouldOverwriteException.new(src, dest)
    end

    $LOG.info { "#{opts[:link] ? "LN" : "MV"} #{src} -> #{dest}" }

    dest.dirname.mkpath

    unless @opts[:pretend]
      if opts[:link]
        File.link(src.to_s, dest.to_s)
      else
        src.rename(dest)
      end
    end
  end

  def handle_inbox
    counter = 0

    @paths[:inbox].each_entry do |p|
      if is_video_file @paths[:inbox] + p
        counter += 1
        sp = ShowPathname.new(@paths[:inbox] + p)

        # This is a temporary destination - organize_library gets run
        # afterwards to find the proper location within
        temp_lib_dest = @paths[:library] + sp.formatted_filename
        safely_move(sp, temp_lib_dest)

        if @paths[:unwatched]
          unwatched_dest = @paths[:unwatched] + sp.formatted_filename
          safely_move(temp_lib_dest, unwatched_dest, :link => true)
        end

        puts "New episode for #{sp.show_name}: #{sp.formatted_filename}"
      end
    end

    $LOG.info "Organizing library..."
    organize_library
    $LOG.info "Done organizing library."

    return counter
  end
end

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.on("-v", "--verbose", "Run verbosely (use multiple times)") do |v|
    $LOG.level -= 1
  end
  opts.on("-p", "--pretend", "Only pretend to perform operations")\
    do |p|
    options[:pretend] = p
    if $LOG.level >= Logger::INFO
      $LOG.level = Logger::INFO
    end
  end
end.parse!

begin
  dir_info = YAML::load_file(File.expand_path("~/.show_organizer.rc"))
  raise Exception.new("No inbox defined") unless dir_info["inbox"]
  raise Exception.new("No library defined") unless dir_info["library"]
rescue Exception => e
  puts <<-EOF
Could not load ~/.show_organizer.rc, for the folowing reason:
  #{e.message}
The file format should look like this (use full paths only):
inbox: /home/username/my_show_inbox
library: /home/username/my_show_library
unwatched: /home/username/place_for_unwatched_links # this is optional
  EOF
  exit 1
end

show_organizer = ShowOrganizer.new(dir_info["inbox"],
                                   dir_info["library"],
                                   dir_info["unwatched"],
                                   options)

if show_organizer.handle_inbox == 0
  puts "No new episodes"
end
