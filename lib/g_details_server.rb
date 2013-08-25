require 'sinatra'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'mongoid'
require_relative 'models/person'
require_relative 'models/organization'
require_relative 'models/github'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
Mongoid.load!("#{File.dirname(__FILE__)}/../config/mongoid.yml")
Mongoid.raise_not_found_error = false

class GDetails < Sinatra::Base
  use Rack::Session::Cookie
  use OmniAuth::Strategies::GoogleOauth2, "812142009790.apps.googleusercontent.com", "B6F0Ben7aGuwMGtHtqdom3kM", :scope => "userinfo.email, userinfo.profile, plus.login, plus.me, plus.circles.write", :prompt => :select_account

  set :session_secret, '123123123'
  disable :protection
  enable :sessions


  configure :development do
    Github.auth_token = '6d4ce5b59bdc7671c8d58cd2ae2c410d49129b1e'
    RestClient.log = STDOUT
  end

  configure :production do
    Github.auth_token = 'e539782f2fa949437e7b13a151cf86798999e2f7'
  end

  get '/auth/:provider/callback' do
    user_hash = request.env['omniauth.auth']
    organization = params[:state]
    unless person = Person.find_by(:google_id => user_hash['extra']['raw_info']['id'], :organization => organization)
      git_hub_user = Github.find_user(organization, user_hash['info']['name'])
      person = Person.create(google_id: user_hash['extra']['raw_info']['id'],
                             name: user_hash['info']['name'],
                             email: user_hash['info']['email'],
                             picture: user_hash['info']['image'],
                             github_name: git_hub_user['login'],
                             github_url: git_hub_user['html_url'],
                             organization: organization)
    end
    session['person'] = person
    redirect "/dashboard/#{organization}"
  end

  get '/' do
    "You need to visit a organization specific page like:  /xxxx  where xxxx is the name of the organization"
  end

  get '/:org' do
    if Organization.find_by(:name => params[:org]).nil?
      raise "Organization #{params[:org]} doesn't exist. Create it first. You can use a CURL command like: curl --data \"logo_url=http://www.#{params[:org]}.co.uk/docroot/img/logo_sb.gif\" http://localhost:4567/#{params[:org]}"
    end
    if (session['person'])
      redirect "/dashboard/#{params[:org]}"
    else
      redirect "/auth/google_oauth2?state=#{params[:org]}"
    end
  end

  get '/auth/failure' do
    "Authentication Error"
  end

  get '/dashboard/:org' do
    unless Organization.find_by(:name => params[:org])
      raise "Organization #{params[:org]} doesn't exist. Create it first. You can use a CURL command like: curl --data \"logo_url=http://www.#{params[:org]}.co.uk/docroot/img/logo_sb.gif\" http://localhost:4567/#{params[:org]}"
    end
    if (!session['person'] or session['person'].organization != params[:org])
      session.clear
      redirect "/#{params[:org]}"
    end
    @people = Person.where(organization: params[:org])
    @organization = Organization.find_by(:name => params[:org])
    haml :dashboard
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

  post '/:org' do
    if Organization.find_by(:name => params[:org])
      raise "Organization already exists"
    else
      Organization.create(name: params[:org], logo_url: params[:logo_url], github_members: Github.members(params[:org]))
    end
  end

  error do
    @error = request.env['sinatra_error'].name
    haml :'500'
  end

end


GDetails.run!