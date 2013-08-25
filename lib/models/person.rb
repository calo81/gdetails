require 'mongoid'
class Person
  
  include Mongoid::Document
  
  field :name
  field :email
  field :github_name
  field :picture
  field :organization
  field :google_id
end