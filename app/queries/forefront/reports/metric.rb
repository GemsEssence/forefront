module Forefront
  module Reports
    # One measure of a MetricReport. `value` is a lambda (row_key, context) → value;
    # a periodic metric is also computed per bucket when the report is broken down.
    Metric = Struct.new(:key, :title, :format, :periodic, :value, keyword_init: true)
  end
end
