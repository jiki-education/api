require "test_helper"

class SerializeChallengeTest < ActiveSupport::TestCase
  test "serializes challenge with all required fields" do
    challenge = create(:challenge, slug: "calculator", title: "Calculator", description: "Build a calculator")

    expected = {
      slug: "calculator",
      title: "Calculator",
      description: "Build a calculator"
    }

    assert_equal expected, SerializeChallenge.(challenge)
  end
end
