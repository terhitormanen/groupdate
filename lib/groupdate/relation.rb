require "active_support/concern"

module Groupdate
  module Relation
    extend ActiveSupport::Concern

    included do
      attr_accessor :groupdate_values
    end

    if ENV["ADAPTER"] == "sqlserver"
      module Calculations
        def calculate(*args, &block)
          default_value = [:count, :sum].include?(args[0]) ? 0 : nil
          Groupdate.process_result(self, super, default_value: default_value)
        end
      end

    else  
      def calculate(*args, &block)
        default_value = [:count, :sum].include?(args[0]) ? 0 : nil
        Groupdate.process_result(self, super, default_value: default_value)
      end
    end
   
  end
end
