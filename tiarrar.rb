require "rubygems"
require "sinatra"
require "haml"
require "yaml"
require "uri"

class Tiarrar
  attr_reader :groups

  def initialize(config, groups)
    @config = YAML.load(open(config))
    @groups = YAML.load(open(groups))

    @myname = @config["myname"]
    @size   = @config["size"].to_i
  end

  def recent
    fetch do |time, user, message|
      true
    end
  end

  def group(group)
    fetch do |time, user, message|
      (@groups[group].include? user) || (user == @myname)
    end
  end

  def search(word)
    regexp = Regexp.new(word)
    fetch do |time, user, message|
      regexp.match(user) || regexp.match(message)
    end
  end

  private
  def fetch
    statuses = []

    files = Dir.glob(File.join(@config['log_directory'], "*")).sort.reverse

    files.each do |file|
      lines = open(file).read.split("\n").reverse

      lines.each do |line|
        if /^(\d\d:\d\d:\d\d) [<>]#[Tt]witter@twitter:([A-Za-z0-9_]+)[<>] (.+)$/ =~ line
          time, user, message = $1, $2, $3
          if yield(time, user, message)
            status = {
              :time => "%s %s" % [File.basename(file, ".txt").gsub(".", "/"), time],
              :user => user,
              :message => message
            }
            statuses << status
          end
        end
        break if statuses.size >= @size
      end
    end

    statuses
  end
end

tiarrar = Tiarrar.new("config.yaml", "groups.yaml")

get "/" do
  @groups = tiarrar.groups.keys
  @statuses = tiarrar.recent
  haml :index
end

get "/groups/:group" do
  @group = params[:group]
  @statuses = tiarrar.group(@group)
  haml :statuses
end

get "/search/" do
  @word = params[:word]
  redirect "/search/#{URI.encode(@word)}"
end

get "/search/:word" do
  @word = params[:word]
  @statuses = tiarrar.search(@word)
  haml :statuses
end
