require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    # Reset Current attributes before each test
    Current.reset
  end

  test "events attribute defaults to nil" do
    assert_nil Current.events
  end

  test "add_event initializes events array and adds event" do
    Current.add_event(:test_event, { foo: "bar" })

    assert_equal 1, Current.events.size
    assert_equal "test_event", Current.events.first[:type]
    assert_equal({ foo: "bar" }, Current.events.first[:data])
  end

  test "add_event converts symbol type to string" do
    Current.add_event(:lesson_completed, {})

    assert_equal "lesson_completed", Current.events.first[:type]
  end

  test "add_event accepts string type" do
    Current.add_event("project_unlocked", {})

    assert_equal "project_unlocked", Current.events.first[:type]
  end

  test "add_event handles empty data hash" do
    Current.add_event(:test_event)

    assert_equal 1, Current.events.size
    assert_empty(Current.events.first[:data])
  end

  test "add_event appends multiple events" do
    Current.add_event(:first_event, { value: 1 })
    Current.add_event(:second_event, { value: 2 })
    Current.add_event(:third_event, { value: 3 })

    assert_equal 3, Current.events.size
    assert_equal "first_event", Current.events[0][:type]
    assert_equal "second_event", Current.events[1][:type]
    assert_equal "third_event", Current.events[2][:type]
  end

  test "add_event preserves data structure" do
    data = {
      lesson_slug: "intro-1",
      completed_at: Time.current,
      metadata: { foo: "bar", nested: { deep: "value" } }
    }

    Current.add_event(:lesson_completed, data)

    stored_data = Current.events.first[:data]
    assert_equal "intro-1", stored_data[:lesson_slug]
    assert_equal data[:completed_at], stored_data[:completed_at]
    assert_equal "bar", stored_data[:metadata][:foo]
    assert_equal "value", stored_data[:metadata][:nested][:deep]
  end

  test "reset clears events" do
    Current.add_event(:test_event, {})
    assert_equal 1, Current.events.size

    Current.reset

    assert_nil Current.events
  end
end
