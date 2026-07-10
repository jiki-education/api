# LEGACY: tests for the pre-rename projects API, kept identical to the old
# public surface. Delete alongside the legacy projects endpoints.
require "test_helper"

class SerializeUserProjectTest < ActiveSupport::TestCase
  test "serializes as SerializeUserChallenge but with the legacy project_slug key" do
    user_challenge = create(:user_challenge, :started)

    expected = SerializeUserChallenge.(user_challenge)
    expected[:project_slug] = expected.delete(:challenge_slug)

    assert_equal expected, SerializeUserProject.(user_challenge)
    refute_includes SerializeUserProject.(user_challenge).keys, :challenge_slug
  end
end
