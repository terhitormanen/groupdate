require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"
require "ostruct"



ENV["TZ"] = "UTC"

adapter = ENV["ADAPTER"]
abort "No adapter specified" unless adapter

puts "Using #{adapter}"
require_relative "adapters/#{adapter}"

require_relative "support/activerecord" unless adapter == "enumerable"

# i18n
I18n.enforce_available_locales = true
I18n.backend.store_translations :de, date: {
  abbr_month_names: %w(Jan Feb Mar Apr Mai Jun Jul Aug Sep Okt Nov Dez).unshift(nil)
},
time: {
  formats: {special: "%b %e, %Y"}
}


class Minitest::Test
  
  def setup
    if enumerable?
      @users = []
    else
      User.delete_all
    end
  end
  
  


  def sqlite?
    ENV["ADAPTER"] == "sqlite"
  end

  def enumerable?
    ENV["ADAPTER"] == "enumerable"
  end

  def postgresql?
    ENV["ADAPTER"] == "postgresql"
  end

  def sqlserver?
    ENV["ADAPTER"] == "sqlserver"
  end

  def create_user(created_at, score = 1)
    created_at = created_at.utc.to_s if created_at.is_a?(Time)

    if enumerable?
      user =
        OpenStruct.new(
          name: "Andrew",
          score: score,
          created_at: created_at ? utc.parse(created_at) : nil,
          created_on: created_at ? Date.parse(created_at) : nil
        )
      @users << user
    else
      user =
        User.new(
          name: "Andrew",
          score: score,
          created_at: created_at ? utc.parse(created_at) : nil,
          created_on: created_at ? Date.parse(created_at) : nil
        )

      if postgresql?
        user.deleted_at = user.created_at
      end

      user.save!

      # hack for Redshift adapter, which doesn't return id on creation...
      user = User.last if user.id.nil?

      user.update_columns(created_at: nil, created_on: nil) if created_at.nil?
    end

    user
  end

  def call_method(method, field, options)
    if enumerable?
      Hash[@users.group_by_period(method, **options) { |u| u.send(field) }.map { |k, v| [k, v.size] }]
    elsif sqlite? && (method == :quarter || options[:time_zone] || options[:day_start] || (Time.zone && options[:time_zone] != false))
      error = assert_raises(Groupdate::Error) { User.group_by_period(method, field, **options).count }
      assert_includes error.message, "not supported for SQLite"
      skip
    else
      User.group_by_period(method, field, **options).count
    end
  end

  def assert_result_time(method, expected, time_str, time_zone = false, **options)
    tz = sqlserver? ? "UTC" : "Pacific Time (US & Canada)"
    expected = {utc.parse(expected).in_time_zone(time_zone ? tz : utc) => 1}
    if sqlserver?
      # only UTC supported for now
      expected = {utc.parse(expected).in_time_zone(utc) => 1}
    end
    
    res = result(method, time_str, time_zone, :created_at, options)
    Rails.logger.info {"assert_result_time res: #{res}, expected: #{expected}"}
    assert_equal expected, res

    if postgresql?
      # test timestamptz
      assert_equal expected, result(method, time_str, time_zone, :deleted_at, options)
    end
  end

  def assert_result_date(method, expected_str, time_str, time_zone = false, options = {})
    create_user time_str
    expected = {Date.parse(expected_str) => 1}
    # Only UTC supported for MS SQL Server
    tz = sqlserver? ? "UTC" : "Pacific Time (US & Canada)"
    res = call_method(method, :created_at, options.merge(time_zone: time_zone ? tz : nil))
    assert_equal expected, res

    # In MS SQL Server only way to get a properly formatted date with time part turncated out is to cast into date
    # but that leaves the time out altogether, so the time part test is meaningless
    if !sqlserver? || (sqlserver? && !%i[day month year].include?(method))
      tzo = sqlserver? ? utc : pt
      expected_time = (time_zone ? tzo : utc).parse(expected_str)
      if options[:day_start]
        expected_time = expected_time.change(hour: options[:day_start], min: (options[:day_start] % 1) * 60)
      end
      expected = {expected_time => 1}
    
      tz = sqlserver? ? "UTC" : "Pacific Time (US & Canada)"
      assert_equal expected, call_method(method, :created_at, options.merge(dates: false, time_zone: time_zone ? tz : nil))
      # assert_equal expected, call_method(method, :created_on, options.merge(time_zone: time_zone ? "Pacific Time (US & Canada)" : nil))
    end
  end

  def assert_result(method, expected, time_str, time_zone = false, options = {})
    assert_equal 1, result(method, time_str, time_zone, :created_at, options)[expected]
  end

  def result(method, time_str, time_zone = false, attribute = :created_at, options = {})
    create_user time_str unless attribute == :deleted_at
    tz = sqlserver? ? "UTC" : "Pacific Time (US & Canada)"
    call_method(method, attribute, options.merge(time_zone: time_zone ? tz : nil))
    #call_method(method, attribute, options.merge(time_zone: tz))
  end

  def utc
    ActiveSupport::TimeZone["Etc/UTC"]
    if sqlserver?
      ActiveSupport::TimeZone["UTC"]
    end
  end

  def pt
    ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
  end
end
