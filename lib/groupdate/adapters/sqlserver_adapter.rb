require "logger"
module Groupdate
    module Adapters
      class SQLServerAdapter < BaseAdapter
        def group_clause
          logger = Logger.new File.new('test_run.log', 'w')
          # TODO Make IANA time zone name -> Windows definition mapping (for now only use UTC)
          # use xxx running it in a container with .NET core
          #time_zone = @time_zone.tzinfo.name
          time_zone = 'UTC' 
         
          day_start_column = "DATEADD(second, - ?, CAST(#{column} AS DATETIMEOFFSET) AT TIME ZONE ?)"
          
          query =
            case period
            when :minute_of_hour
              ["DATEPART(minute, #{day_start_column})", day_start, time_zone]
            when :hour_of_day
              ["DATEPART(hour, #{day_start_column})", day_start, time_zone]
            when :day_of_week
              ["DATEPART(weekday, #{day_start_column})", day_start, time_zone]
            when :day_of_month
              ["DATEPART(day, #{day_start_column})", day_start, time_zone]
            when :day_of_year
              ["DATEPART(dayofyear, #{day_start_column})", day_start, time_zone]
            when :month_of_year
              ["DATEPART(month, #{day_start_column})", day_start, time_zone]
            when :week
              raise Groupdate::Error, 'by_week not implemented yet'
            when :quarter
              raise Groupdate::Error, 'by_quarter not implemented yet'
              # ["CONVERT_TZ(DATE_FORMAT(DATE(CONCAT(YEAR(#{day_start_column}), '-', LPAD(1 + 3 * (QUARTER(#{day_start_column}) - 1), 2, '00'), '-01')), '%Y-%m-%d %H:%i:%S') + INTERVAL ? second, ?, '+00:00')", time_zone, day_start, time_zone, day_start, day_start, time_zone]
            when :custom
              ["DATEADD(second, FLOOR(CAST(DATEDIFF_BIG(millisecond, CAST('1970-01-01 00:00:00' AS DATETIME2), CAST(#{column} AS DATETIME2))/1000 AS int) / ?) * ?, '1970-01-01')", n_seconds, n_seconds]
            else
              raise Groupdate::Error, 'Not implemented yet' unless day_start.zero?
              logger.info "period: #{period}"
              day_start_column = "CAST(#{column} AS DATETIMEOFFSET) AT TIME ZONE ?"
              # :second, :minute, :hour, :day, :month, :year
              
                case period
                when :second
                  day_start_column = "CAST(#{column} AS DATETIMEOFFSET)"
                  ["DATEADD(millisecond, - DATEPART(millisecond, #{day_start_column}), #{day_start_column}) AT TIME ZONE ?", time_zone]
                when :minute
                  ["DATEADD(minute, DATEDIFF(minute, 0, #{day_start_column}), 0) AT TIME ZONE ?", time_zone, time_zone]
                when :hour
                  ["DATEADD(hour, DATEDIFF(hour, 0, #{day_start_column}), 0) AT TIME ZONE ?", time_zone, time_zone]
                when :day
                  ["CAST(DATEADD(day, DATEDIFF(day, 0, #{day_start_column}), 0) AT TIME ZONE ? AS DATETIME)", time_zone, time_zone]
                when :month
                  ["CAST(DATEADD(month, DATEDIFF(month, 0, #{day_start_column}), 0) AT TIME ZONE ? AS DATETIME)", time_zone, time_zone]
                when :year
                  ["CAST(DATEADD(year, DATEDIFF(year, 0, #{day_start_column}), 0)  AT TIME ZONE ? AS DATETIME)", time_zone, time_zone]
                else 
                  #["DATE_TRUNC(?, #{day_start_column}) AT TIME ZONE ?", period, time_zone, day_start_interval, time_zone]
                  #["(DATE_TRUNC(?, #{day_start_column}) + INTERVAL ?) AT TIME ZONE ?", period, time_zone, day_start_interval, day_start_interval, time_zone]
                  raise Groupdate::Error, 'Not implemented yet'
                end
            end
            logger.info "query: #{query}"
          @relation.send(:sanitize_sql_array, query)
        end
  

      end
    end
end
  