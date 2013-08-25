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
      member['name'].downcase == name.downcase
    end
    if members.empty
      member = members.select do |member|
        last_name(member['name']) == name.downcase or last_name(member['name']) == last_name(name) or member['name'] == last_name(name)
      end
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

  def self.last_name(name)
    names = name.split(" ")
    if names.size > 1
      return names[1].downcase
    end
  end
end