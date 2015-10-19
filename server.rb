require 'json'
require 'octokit'
require 'sinatra'

ACCESS_TOKEN = ENV['GITTOOLS_TOKEN']

before do
  @client ||= Octokit::Client.new(:access_token => ACCESS_TOKEN)
end

post '/' do
  @payload = JSON.parse(params[:payload])

  # puts JSON.pretty_generate(@payload)

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

    @client.create_status(repo, hash, 'pending', :context => 'gittools/limits/subject', :description => 'The GitTools check is pending ...')
    @client.create_status(repo, hash, 'pending', :context => 'gittools', :description => 'The GitTools check is pending ...')

    commits = @client.pull_request_commits(repo, pull['number'])
    puts JSON.pretty_generate(commits)

    commits.each do |commit|
      if commit['commit']['message'].length >= limits[:subject]
        raise Exception.new 'the subject line must fit in 50 characters'
      end
    end

    @client.create_status(repo, hash, 'success', :context => 'gittools/limits/subject', :description => 'The GitTools check passed')

    # Do another work.
    @client.create_status(repo, hash, 'success', :context => 'gittools', :description => 'The GitTools check passed')
  rescue Exception => e
    @client.create_status(repo, hash, 'error', :context => 'gittools', :description => "The GitTools check failed")
  end
end
