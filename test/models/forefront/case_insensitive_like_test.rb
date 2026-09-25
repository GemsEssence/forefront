require "test_helper"
require "minitest/mock"

# Forefront's search filters must work on whatever database the host app uses.
class Forefront::CaseInsensitiveLikeTest < ActiveSupport::TestCase
  test "uses ILIKE on PostgreSQL" do
    Forefront::ApplicationRecord.connection.stub(:adapter_name, "PostgreSQL") do
      assert_equal "ILIKE", Forefront::ApplicationRecord.case_insensitive_like
    end
  end

  test "falls back to LIKE, which ignores ASCII case, on SQLite and MySQL" do
    %w[SQLite Mysql2 Trilogy].each do |adapter|
      Forefront::ApplicationRecord.connection.stub(:adapter_name, adapter) do
        assert_equal "LIKE", Forefront::ApplicationRecord.case_insensitive_like, adapter
      end
    end
  end

  test "text search still matches regardless of case" do
    Forefront::Customer.create!(name: "Acme Widgets", phone: "5550100")

    assert_equal [ "Acme Widgets" ], Forefront::CustomerServices::Filter.new(filters: { search: "acme" }).call.pluck(:name)
    assert_equal [ "Acme Widgets" ], Forefront::Customer.by_name("WIDGET").pluck(:name)
  end
end
