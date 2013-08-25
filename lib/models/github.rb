require 'rest_client'
require 'json'
class Github
  ORG_MEMBERS_URL = "https://api.github.com/orgs/:org/members?access_token=:auth_token"
  USER_URL = "https://api.github.com/users/:user?access_token=:auth_token"

  def self.auth_token=(token)
    # deliberately changing constant
    ORG_MEMBERS_URL.gsub!(":auth_token", token)
    USER_URL.gsub!(":auth_token", token)
  end

  def self.find_user(organization, name)
    members = Organization.where(:name => organization).first['github_members']
    member = members.select do |member|
      member['name'] == name
    end
    member.empty? ? {} : member[0]
  end

  def self.members(organization)
    members_json = RestClient.get(ORG_MEMBERS_URL.gsub(":org", organization))
    members = JSON.parse(members_json)
    members.map do |member|
      member_details_json = RestClient.get(USER_URL.gsub(":user", member['login']))
      JSON.parse(member_details_json)
    end
  end
end