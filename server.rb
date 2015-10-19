require 'json'
require 'octokit'
require 'sinatra'

ACCESS_TOKEN = ENV['GITTOOLS_TOKEN']

before do
  @client ||= Octokit::Client.new(:access_token => ACCESS_TOKEN)
end

post '/' do
  @payload = JSON.parse(params[:payload])
  puts :payload => @payload

  case request.env['HTTP_X_GITHUB_EVENT']
  when "pull_request"
    if ["opened", "reopened", "synchronize"].include? @payload["action"]
      process(@payload["pull_request"])
    end
  end
end

helpers do
  def process(pull)
    types = ['feat', 'fix', 'perf', 'chore', 'misc', 'refactor', 'style', 'docs', 'version', 'revert', 'tests', 'ci']

    limits = {
        :subject => 50,
        :body    => 72,
    }

    repo = pull['base']['repo']['full_name']
    hash = pull['head']['sha']

    @client.create_status(repo, hash, 'pending', :context => 'gittools', :description => 'The GitTools check is pending ...')

    commits = @client.pull_commits repo, request[:number]
    commits.each do |commit|
      if commit[:commit][:message].len >= 50
        raise Exception.new 'the subject line must fit in 50 characters'
      end
    end

  rescue Exception => e
    puts :error => e
    # @client.create_status(repo, hash, 'error', :context => 'gittools', :description => "The GitTools check failed: #{e}")
  ensure
    @client.create_status(repo, hash, 'success', :context => 'gittools', :description => 'The GitTools check passed')
  end
end
