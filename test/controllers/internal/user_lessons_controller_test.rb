require "test_helper"

class Internal::UserLessonsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @level = create(:level)
    @lesson = create(:lesson, :exercise, level: @level)
    @user_level = create(:user_level, user: @current_user, level: @level)
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_lesson_path, args: ["solve-a-maze"], method: :get
  guard_incorrect_token! :start_internal_user_lesson_path, args: ["solve-a-maze"], method: :post
  guard_incorrect_token! :complete_internal_user_lesson_path, args: ["solve-a-maze"], method: :patch
  guard_incorrect_token! :rate_internal_user_lesson_path, args: ["solve-a-maze"], method: :patch
  guard_incorrect_token! :walkthrough_video_percentage_internal_user_lesson_path, args: ["solve-a-maze"], method: :patch

  # GET /v1/user_lessons/:slug tests
  test "GET show returns user lesson progress" do
    user_lesson = create(:user_lesson, user: @current_user, lesson: @lesson)
    serialized_data = { lesson_slug: @lesson.slug, status: "started", data: {} }

    SerializeUserLesson.expects(:call).with(user_lesson).returns(serialized_data)

    get internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success
    assert_json_response({ user_lesson: serialized_data })
  end

  test "GET show returns 404 when user_lesson does not exist" do
    get internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_json_error(:not_found)
  end

  test "GET show returns 404 for non-existent lesson" do
    get internal_user_lesson_path(lesson_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end

  # POST /v1/user_lessons/:slug/start tests
  test "POST start successfully starts a lesson" do
    post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "POST start delegates to UserLesson::Start command" do
    UserLesson::Start.expects(:call).with(@current_user, @lesson)

    post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success
  end

  test "POST start returns 404 for non-existent lesson" do
    post start_internal_user_lesson_path(lesson_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end

  test "POST start is idempotent" do
    assert_difference "UserLesson.count", 1 do
      post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success

    assert_no_difference "UserLesson.count" do
      post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success
  end

  test "POST start creates user_lesson record" do
    assert_difference "UserLesson.count", 1 do
      post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success
  end

  test "POST start does not create duplicate user_lessons" do
    # First start
    post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    # Second start should not create another record
    assert_no_difference "UserLesson.count" do
      post start_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success
  end

  # PATCH /v1/user_lessons/:slug/complete tests
  test "PATCH complete successfully completes a lesson" do
    create(:user_lesson, user: @current_user, lesson: @lesson)

    patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "PATCH complete delegates to UserLesson::Complete command" do
    create(:user_lesson, user: @current_user, lesson: @lesson)
    UserLesson::Complete.expects(:call).with(@current_user, @lesson)

    patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success
  end

  test "PATCH complete returns 404 for non-existent lesson" do
    patch complete_internal_user_lesson_path(lesson_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end

  test "PATCH complete is idempotent" do
    create(:user_lesson, user: @current_user, lesson: @lesson)

    # First completion
    patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_response :success

    # Second completion should be idempotent
    assert_no_difference "UserLesson.count" do
      patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success
  end

  test "PATCH complete returns 422 when lesson not started" do
    # No user_lesson created

    patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :user_lesson_not_found)
  end

  test "PATCH complete preserves lesson record on re-completion" do
    create(:user_lesson, user: @current_user, lesson: @lesson)

    # First completion
    patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
      as: :json

    # Second completion should not create another record
    assert_no_difference "UserLesson.count" do
      patch complete_internal_user_lesson_path(lesson_slug: @lesson.slug),
        as: :json
    end

    assert_response :success
    assert_equal 1, UserLesson.where(user: @current_user, lesson: @lesson).count
  end

  test "PATCH complete emits events for unlocked concept and project" do
    Prosopite.finish

    concept = create(:concept, slug: "variables", title: "Variables")
    project = create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")
    level = create(:level)
    lesson = create(:lesson, :exercise, level:, unlocked_concept: concept, unlocked_project: project)
    create(:user_level, user: @current_user, level:)
    create(:user_lesson, user: @current_user, lesson:)

    patch complete_internal_user_lesson_path(lesson_slug: lesson.slug),
      as: :json

    assert_response :success
    assert_json_response({
      meta: {
        events: [
          {
            type: "concept_unlocked",
            data: {
              concept: SerializeConcept.(concept)
            }
          },
          {
            type: "project_unlocked",
            data: {
              project: SerializeProject.(project)
            }
          }
        ]
      }
    })
  end

  test "PATCH complete emits lesson_unlocked event when there is a next lesson" do
    level = create(:level)
    lesson1 = create(:lesson, :exercise, level:, slug: "first-lesson", position: 1)
    create(:lesson, :exercise, level:, slug: "second-lesson", position: 2)
    create(:user_level, user: @current_user, level:)
    create(:user_lesson, user: @current_user, lesson: lesson1)

    patch complete_internal_user_lesson_path(lesson_slug: lesson1.slug),
      as: :json

    assert_response :success
    assert_json_response({
      meta: {
        events: [
          {
            type: "lesson_unlocked",
            data: {
              lesson_slug: "second-lesson"
            }
          }
        ]
      }
    })
  end

  test "PATCH complete does not emit lesson_unlocked event for last lesson in level" do
    level = create(:level)
    lesson = create(:lesson, :exercise, level:, slug: "only-lesson", position: 1)
    create(:user_level, user: @current_user, level:)
    create(:user_lesson, user: @current_user, lesson:)

    patch complete_internal_user_lesson_path(lesson_slug: lesson.slug),
      as: :json

    assert_response :success
    assert_json_response({
      meta: {
        events: []
      }
    })
  end

  # PATCH /v1/user_lessons/:slug/rate tests
  test "PATCH rate successfully sets ratings" do
    create(:user_lesson, user: @current_user, lesson: @lesson)

    UserLesson::SetRatings.expects(:call).with(@current_user, @lesson, 3, 5)

    patch rate_internal_user_lesson_path(lesson_slug: @lesson.slug),
      params: { difficulty_rating: 3, fun_rating: 5 },
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "PATCH rate returns 404 for non-existent lesson" do
    patch rate_internal_user_lesson_path(lesson_slug: "non-existent-slug"),
      params: { difficulty_rating: 3, fun_rating: 5 },
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end

  test "PATCH rate returns 422 when user_lesson not found" do
    patch rate_internal_user_lesson_path(lesson_slug: @lesson.slug),
      params: { difficulty_rating: 3, fun_rating: 5 },
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :user_lesson_not_found)
  end

  # PATCH /v1/user_lessons/:slug/walkthrough_video_percentage tests
  test "PATCH walkthrough_video_percentage delegates to command" do
    create(:user_lesson, user: @current_user, lesson: @lesson)

    UserLesson::SetWalkthroughVideoPercentage.expects(:call).with(@current_user, @lesson, 50)

    patch walkthrough_video_percentage_internal_user_lesson_path(lesson_slug: @lesson.slug),
      params: { percentage: 50 },
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "PATCH walkthrough_video_percentage returns 404 for non-existent lesson" do
    patch walkthrough_video_percentage_internal_user_lesson_path(lesson_slug: "non-existent-slug"),
      params: { percentage: 50 },
      as: :json

    assert_json_error(:not_found, error_type: :lesson_not_found)
  end

  test "PATCH walkthrough_video_percentage returns 422 when user_lesson not found" do
    patch walkthrough_video_percentage_internal_user_lesson_path(lesson_slug: @lesson.slug),
      params: { percentage: 50 },
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :user_lesson_not_found)
  end

  # Error handler tests
  test "POST start returns 422 when lesson in progress" do
    lesson1 = create(:lesson, :exercise, level: @level)
    lesson2 = create(:lesson, :exercise, level: @level)
    in_progress = create(:user_lesson, user: @current_user, lesson: lesson1, completed_at: nil)
    @user_level.update!(current_user_lesson: in_progress)

    post start_internal_user_lesson_path(lesson_slug: lesson2.slug),
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :lesson_in_progress)
  end

  test "POST start returns 403 when user level not found" do
    other_level = create(:level, slug: "other-level", position: 999)
    other_lesson = create(:lesson, :exercise, level: other_level)
    # User is enrolled in course but no user_level for this level
    create(:user_course, user: @current_user, course: other_level.course)

    post start_internal_user_lesson_path(lesson_slug: other_lesson.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :user_level_not_found)
  end

  test "POST start returns 422 when trying to start lesson in next level before completing current" do
    course = create(:course)
    level1 = create(:level, course:, position: 100, slug: "level-100")
    level2 = create(:level, course:, position: 200, slug: "level-200")
    lesson1 = create(:lesson, :exercise, level: level1)
    lesson2 = create(:lesson, :exercise, level: level2)
    user_course = create(:user_course, user: @current_user, course:)
    user_level1 = create(:user_level, user: @current_user, level: level1)
    create(:user_level, user: @current_user, level: level2)
    user_course.update!(current_user_level: user_level1)
    create(:user_lesson, user: @current_user, lesson: lesson1, completed_at: Time.current)
    # level1 is not fully complete (only 1 lesson)

    post start_internal_user_lesson_path(lesson_slug: lesson2.slug),
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :level_not_completed)
  end
end
