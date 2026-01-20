require "test_helper"

class AssistantConversation::CreateConversationTokenTest < ActiveSupport::TestCase
  test "creates conversation token for premium user" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    lesson = create(:lesson, :exercise, slug: "test-lesson", data: { slug: 'jiki/intro/test' })

    token = AssistantConversation::CreateConversationToken.(user, lesson)

    assert token.present?

    # Verify token contents
    payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' }).first
    assert_equal user.id, payload['sub']
    assert_equal "test-lesson", payload['lesson_slug']
    assert_equal "jiki/intro/test", payload['exercise_slug']
    assert payload['exp'].present?
    assert payload['iat'].present?
  end

  test "creates conversation token for standard user first lesson" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson = create(:lesson, :exercise)

    token = AssistantConversation::CreateConversationToken.(user, lesson)

    assert token.present?
  end

  test "raises error for standard user on different lesson" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    lesson1 = create(:lesson, :exercise)
    lesson2 = create(:lesson, :exercise)
    create(:assistant_conversation, user:, context: lesson1)

    assert_raises(AssistantConversationAccessDeniedError) do
      AssistantConversation::CreateConversationToken.(user, lesson2)
    end
  end

  test "creates or finds existing conversation" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    lesson = create(:lesson, :exercise)

    assert_difference 'AssistantConversation.count', 1 do
      AssistantConversation::CreateConversationToken.(user, lesson)
    end

    assert_no_difference 'AssistantConversation.count' do
      AssistantConversation::CreateConversationToken.(user, lesson)
    end
  end

  test "token expires in 1 hour" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    lesson = create(:lesson, :exercise)

    freeze_time do
      token = AssistantConversation::CreateConversationToken.(user, lesson)

      payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' }).first
      expected_exp = 1.hour.from_now.to_i

      assert_equal expected_exp, payload['exp']
    end
  end

  test "uses slug from lesson data for exercise_slug" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    lesson = create(:lesson, :exercise, data: { slug: "my-exercise-slug" })

    token = AssistantConversation::CreateConversationToken.(user, lesson)

    payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' }).first
    assert_equal "my-exercise-slug", payload['exercise_slug']
  end
end
