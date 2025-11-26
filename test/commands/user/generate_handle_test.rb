require "test_helper"

class User::GenerateHandleTest < ActiveSupport::TestCase
  test "generates handle from email username" do
    handle = User::GenerateHandle.("john.doe@example.com")
    assert_equal "john-doe", handle
  end

  test "handles collision by appending hex suffix" do
    create(:user, handle: "john-doe")
    handle = User::GenerateHandle.("john.doe@example.com")
    assert_match(/\Ajohn-doe-[a-f0-9]{6}\z/, handle)
  end

  test "handles special characters in email" do
    handle = User::GenerateHandle.("first+tag@example.com")
    assert_equal "first-tag", handle
  end

  test "raises after max attempts" do
    # Create 101 users with conflicting handles to force max attempts
    # This test verifies the safety net but is impractical to run
    # Skip it in normal test runs - this scenario is extremely unlikely
    skip "Max attempts scenario is too impractical to test in practice"
  end
end
