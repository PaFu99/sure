# Splits a report period into monthly or ISO-weekly intervals for the
# transactions breakdown. Intervals at the edges are clipped to the period so
# partial months/weeks only cover dates inside it.
class Reports::BreakdownIntervals
  include Enumerable

  GRANULARITIES = %w[monthly weekly].freeze
  DEFAULT_GRANULARITY = "monthly".freeze

  Interval = Data.define(:key, :start_date, :end_date, :granularity) do
    def weekly?
      granularity == "weekly"
    end

    def label
      if weekly?
        I18n.t("reports.transactions_breakdown.interval.week_label", week: start_date.cweek)
      else
        I18n.l(start_date, format: :short_month_year)
      end
    end

    def range_label
      I18n.t(
        "reports.transactions_breakdown.interval.range",
        start: I18n.l(start_date, format: :short).strip,
        end: I18n.l(end_date, format: :short).strip
      )
    end
  end

  attr_reader :start_date, :end_date, :granularity

  def self.normalize_granularity(value)
    GRANULARITIES.include?(value.to_s) ? value.to_s : DEFAULT_GRANULARITY
  end

  def initialize(start_date:, end_date:, granularity: DEFAULT_GRANULARITY)
    @start_date = start_date
    @end_date = end_date
    @granularity = self.class.normalize_granularity(granularity)
  end

  def each(&block)
    intervals.each(&block)
  end

  def weekly?
    granularity == "weekly"
  end

  # Bucket key for a date, matching the key of the interval that contains it.
  def key_for(date)
    weekly? ? format("%04d-W%02d", date.cwyear, date.cweek) : date.strftime("%Y-%m")
  end

  private
    def intervals
      @intervals ||= begin
        result = []
        cursor = start_date

        while cursor <= end_date
          interval_end = [ weekly? ? cursor.end_of_week(:monday) : cursor.end_of_month, end_date ].min
          result << Interval.new(key: key_for(cursor), start_date: cursor, end_date: interval_end, granularity: granularity)
          cursor = interval_end + 1.day
        end

        result
      end
    end
end
