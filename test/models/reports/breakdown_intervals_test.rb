require "test_helper"

class Reports::BreakdownIntervalsTest < ActiveSupport::TestCase
  test "monthly intervals cover each month and clip partial months to the period" do
    intervals = Reports::BreakdownIntervals.new(start_date: Date.new(2026, 1, 15), end_date: Date.new(2026, 3, 10), granularity: "monthly").to_a

    assert_equal %w[2026-01 2026-02 2026-03], intervals.map(&:key)
    assert_equal [ Date.new(2026, 1, 15), Date.new(2026, 2, 1), Date.new(2026, 3, 1) ], intervals.map(&:start_date)
    assert_equal [ Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 10) ], intervals.map(&:end_date)
  end

  test "weekly intervals follow ISO weeks and clip partial weeks to the period" do
    # 2026-01-07 is a Wednesday (ISO week 2), 2026-01-20 is a Tuesday (ISO week 4)
    intervals = Reports::BreakdownIntervals.new(start_date: Date.new(2026, 1, 7), end_date: Date.new(2026, 1, 20), granularity: "weekly").to_a

    assert_equal %w[2026-W02 2026-W03 2026-W04], intervals.map(&:key)
    assert_equal [ Date.new(2026, 1, 7), Date.new(2026, 1, 12), Date.new(2026, 1, 19) ], intervals.map(&:start_date)
    assert_equal [ Date.new(2026, 1, 11), Date.new(2026, 1, 18), Date.new(2026, 1, 20) ], intervals.map(&:end_date)
  end

  test "weekly intervals use the ISO week-based year across the year boundary" do
    # 2020-12-28..2021-01-03 is ISO week 53 of 2020
    breakdown = Reports::BreakdownIntervals.new(start_date: Date.new(2020, 12, 30), end_date: Date.new(2021, 1, 5), granularity: "weekly")

    assert_equal %w[2020-W53 2021-W01], breakdown.map(&:key)
    assert_equal "2020-W53", breakdown.key_for(Date.new(2021, 1, 2))
    assert_equal "2021-W01", breakdown.key_for(Date.new(2021, 1, 4))
  end

  test "key_for matches the interval containing the date" do
    breakdown = Reports::BreakdownIntervals.new(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), granularity: "weekly")

    breakdown.each do |interval|
      assert_equal interval.key, breakdown.key_for(interval.start_date)
      assert_equal interval.key, breakdown.key_for(interval.end_date)
    end
  end

  test "labels use localized month and calendar week formats" do
    I18n.with_locale(:de) do
      month = Reports::BreakdownIntervals.new(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31), granularity: "monthly").first
      week = Reports::BreakdownIntervals.new(start_date: Date.new(2026, 8, 3), end_date: Date.new(2026, 8, 9), granularity: "weekly").first

      assert_equal I18n.l(Date.new(2026, 1, 1), format: :short_month_year), month.label
      assert_equal "KW 32", week.label
      assert_equal "3. Aug – 9. Aug", week.range_label
    end
  end

  test "unknown granularity falls back to monthly" do
    assert_equal "monthly", Reports::BreakdownIntervals.normalize_granularity("daily")
    assert_equal "monthly", Reports::BreakdownIntervals.normalize_granularity(nil)
    assert_equal "weekly", Reports::BreakdownIntervals.normalize_granularity("weekly")
  end
end
