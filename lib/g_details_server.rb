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


  set :session_secret, '123123123'
  disable :protection
  enable :sessions


  configure :development do
    load(File.dirname(__FILE__)+"/../.env")
    Github.auth_token = ENV['GITHUB_AUTH_TOKEN']
    RestClient.log = STDOUT
    use OmniAuth::Strategies::GoogleOauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], :scope => "userinfo.email, userinfo.profile", :prompt => :select_account
  end

  configure :production do
    Github.auth_token = ENV['GITHUB_AUTH_TOKEN']
    use OmniAuth::Strategies::GoogleOauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], :scope => "userinfo.email, userinfo.profile", :prompt => :select_account
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

  get '/logout' do
    session.clear
    redirect '/'
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



  post '/:org' do
    if Organization.find_by(:name => params[:org])
      raise "Organization already exists"
    else
      Organization.create(name: params[:org], logo_url: params[:logo_url], github_members: Github.members(params[:org]))
    end
  end

  error do |error|
    @error = error
    haml :'500'
  end

end


GDetails.run!