require 'mongoid'
class Organization

  include Mongoid::Document

  field :name
  field :logo_url

end