require "test_helper"

class SerializeChallengeTest < ActiveSupport::TestCase
  test "serializes challenge with all required fields" do
    challenge = create(:challenge, slug: "calculator", exercise_slug: "calculator")

    expected = {
      slug: "calculator",
      exercise_slug: "calculator"
    }

    assert_equal expected, SerializeChallenge.(challenge)
  end

  # Challenges are exercises on the front end - their copy comes from the
  # curriculum exercise named by exercise_slug.
  test "does not include title or description" do
    result = SerializeChallenge.(create(:challenge))

    refute result.key?(:title)
    refute result.key?(:description)
  end
end
