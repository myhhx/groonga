class TestAndOrder < ExpressionRewriterTestCase
  def setup
    Groonga::Schema.define do |schema|
      schema.create_table("expression_rewriters",
                          :type => :hash,
                          :key_type => :short_text) do |table|
        table.text("plugin_name")
      end

      schema.create_table("Logs") do |table|
        table.time("created_at")
        table.time("updated_at")
      end

      schema.create_table("Timestamps",
                          :type => :patricia_trie,
                          :key_type => :time) do |table|
        table.index("Logs.created_at")
        table.index("Logs.updated_at")
      end
    end

    @rewriters = Groonga["expression_rewriters"]
    @rewriters.add("optimizer",
                   :plugin_name => "expression_rewriters/optimizer")

    @logs = Groonga["Logs"]
    setup_logs
    setup_expression(@logs)
  end

  def setup_logs
    100.times do
      @logs.add(:created_at => "2015-10-01 00:00:00",
                :updated_at => "2015-10-01 00:00:00")
    end

    50.times do
      @logs.add(:created_at => "2015-10-02 00:00:00",
                :updated_at => "2015-10-02 00:00:00")
    end

    10.times do
      @logs.add(:created_at => "2015-10-03 00:00:00",
                :updated_at => "2015-10-03 00:00:00")
    end
  end

  def teardown
    teardown_expression
  end

  def test_range
    code =
      "created_at <= '2015-10-01 00:00:00' && " +
      "updated_at >= '2015-10-03 00:00:00'"
    assert_equal(<<-DUMP, dump_rewritten_plan(code))
[0]
  op:         <greater_equal>
  logical_op: <or>
  query:      <"2015-10-03 00:00:00">
  expr:       <0..2>
[1]
  op:         <less_equal>
  logical_op: <and>
  query:      <"2015-10-01 00:00:00">
  expr:       <3..5>
    DUMP
  end
end
