require "active_record"
require "activerecord-sqlserver-adapter"
require "groupdate/query_methods"
require "groupdate/relation"

ActiveRecord::Base.extend(Groupdate::QueryMethods)
#if ENV["ADAPTER"]=='sqlserver'
  ActiveRecord::ConnectionAdapters::SQLServer::CoreExt::Calculations.prepend(Groupdate::Relation::Calculations)
  ActiveRecord::Relation.include(Groupdate::Relation)
#else   
#  ActiveRecord::Relation.include(Groupdate::Relation)
#end
