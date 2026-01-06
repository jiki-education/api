require "test_helper"

class User::AcquiredBadge::RevealTest < ActiveSupport::TestCase
  test "marks badge as revealed" do
    acquired_badge = create(:user_acquired_badge, revealed: false)

    User::AcquiredBadge::Reveal.(acquired_badge)

    assert acquired_badge.reload.revealed?
  end

  test "is idempotent when already revealed" do
    acquired_badge = create(:user_acquired_badge, :revealed)

    assert_no_changes -> { acquired_badge.reload.updated_at } do
      User::AcquiredBadge::Reveal.(acquired_badge)
    end

    assert acquired_badge.reload.revealed?
  end

  test "returns the acquired badge" do
    acquired_badge = create(:user_acquired_badge, revealed: false)

    result = User::AcquiredBadge::Reveal.(acquired_badge)

    assert_equal acquired_badge, result
  end

  test "persists the change to the database" do
    acquired_badge = create(:user_acquired_badge, revealed: false)

    User::AcquiredBadge::Reveal.(acquired_badge)

    # Create a fresh instance from database
    fresh_instance = User::AcquiredBadge.find(acquired_badge.id)
    assert fresh_instance.revealed?
  end
end
