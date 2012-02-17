#--
# Copyright (c) 2011 {PartyEarth LLC}[http://partyearth.com]
# mailto:kgoslar@partyearth.com
#++
module SneakySave
  extend ActiveSupport::Concern

  module InstanceMethods

    # Saves record without running callbacks/validations.
    # Returns true if any record is changed.
    #
    # @note - Does not reload updated record by default.
    #       - Does not save associated collections.
    #       - Saves only belongs_to relations.
    #       
    # @return [false, true]
    def sneaky_save
      begin
        new_record? ? sneaky_create : sneaky_update
      rescue ActiveRecord::StatementInvalid
        false
      end
    end

    protected

      # Makes INSERT query in database without running any callbacks.
      # 
      # @return [false, true]
      def sneaky_create
        if self.id.nil? && connection.prefetch_primary_key?(self.class.table_name)
          self.id = connection.next_sequence_value(self.class.sequence_name)
        end

        attributes_values = send :arel_attributes_values

        if self.id.nil? && !connection.prefetch_primary_key?(self.class.table_name)
          # Remove the id field for databases like Postgres which will raise an error on id being NULL
          attributes_values.reject! { |key,val| key.name == 'id' }
        end

        new_id = if attributes_values.empty?
          self.class.unscoped.insert connection.empty_insert_statement_value
        else
          self.class.unscoped.insert attributes_values
        end

        @new_record = false
        !!(self.id ||= new_id)
      end

      # Makes update query without running callbacks.
      #
      # @return [false, true]
      def sneaky_update

        # Handle no changes.
        return true unless changes.any?

        # Here we have changes --> save them.
        pk = self.class.primary_key
        original_id = changed_attributes.has_key?(pk) ? changes[pk].first : send(pk)
        !self.class.update_all(attributes, pk => original_id).zero?
      end
  end
end

ActiveRecord::Base.send :include, SneakySave
