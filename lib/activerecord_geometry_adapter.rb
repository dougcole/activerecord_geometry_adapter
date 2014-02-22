require 'active_support'
require 'active_record'
require 'georuby'
require 'active_record/connection_adapters/postgresql/oid'
require 'active_record/connection_adapters/postgresql/quoting'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module Quoting

        def type_cast(value, column, array_member = false)
          return super(value, column) unless column

          case value
          when Range
            return super(value, column) unless /range$/ =~ column.sql_type
            PostgreSQLColumn.range_to_string(value)
          when NilClass
            if column.array && array_member
              'NULL'
            elsif column.array
              value
            else
              super(value, column)
            end
          when Array
            case column.sql_type
            when 'point' then PostgreSQLColumn.point_to_string(value)
            when 'json' then PostgreSQLColumn.json_to_string(value)
            else
              return super(value, column) unless column.array
              PostgreSQLColumn.array_to_string(value, column, self)
            end
          when String
            return super(value, column) unless 'bytea' == column.sql_type
            { :value => value, :format => 1 }
          when Hash
            case column.sql_type
            when 'hstore' then PostgreSQLColumn.hstore_to_string(value)
            when 'json' then PostgreSQLColumn.json_to_string(value)
            else super(value, column)
            end
          when IPAddr
            return super(value, column) unless ['inet','cidr'].include? column.sql_type
            PostgreSQLColumn.cidr_to_string(value)
          when GeoRuby::SimpleFeatures::Geometry
            value.as_hex_ewkb
          else
            super(value, column)
          end
        end
      end

      module OID

        class Geometry < Type
          def type_cast(value)
            puts "type_cast"
            return nil if value.nil?
            GeoRuby::SimpleFeatures::Geometry.from_hex_ewkb(value)
          end

          def type_cast_for_write(value)
            puts "type_cast_for_write"
            if value === String
              value
            elsif value.nil?
              'NULL'
            else
              value.as_hex_ewkb
            end
          end
        end


        register_type 'geometry', OID::Geometry.new
      end
    end
  end
end

###TESTING
#
require 'pg'
con = ActiveRecord::Base.establish_connection({adapter: 'postgresql', username: 'shackserv', password: 'password', database: 'estately_dev'})

class Property < ActiveRecord::Base

end
