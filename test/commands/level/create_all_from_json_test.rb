require "test_helper"

class Level::CreateAllFromJsonTest < ActiveSupport::TestCase
  test "imports levels and lessons from valid JSON" do
    course = create(:course)
    file_path = Rails.root.join("db", "seeds", "curriculum.json")

    result = Level::CreateAllFromJson.(course, file_path.to_s)

    assert_empty result[:orphaned_levels]
    assert_empty result[:orphaned_lessons]

    # Verify levels were created
    using_functions = Level.find_by(slug: "using-functions")
    assert using_functions
    assert_equal "Using Functions", using_functions.title
    assert_equal 1, using_functions.position
    assert_equal course, using_functions.course
    assert using_functions.uuid.present?

    strings_and_colors = Level.find_by(slug: "strings-and-colors")
    assert strings_and_colors
    assert_equal "Strings and Colors", strings_and_colors.title
    assert_equal 2, strings_and_colors.position

    # Verify lessons were created
    assert_equal 8, using_functions.lessons.count
    first_lesson = using_functions.lessons.find_by(slug: "maze-solve-basic")
    assert first_lesson
    assert_equal "Solve the Maze", first_lesson.title
    assert_equal "exercise", first_lesson.type
    assert_equal({ slug: "maze-solve-basic" }, first_lesson.data)
    assert_equal 2, first_lesson.position
    assert first_lesson.uuid.present?
  end

  test "is idempotent - running twice keeps the same records" do
    course = create(:course)
    file_path = Rails.root.join("db", "seeds", "curriculum.json").to_s

    Level::CreateAllFromJson.(course, file_path)
    level_ids = Level.pluck(:id).sort
    lesson_ids = Lesson.pluck(:id).sort

    Level::CreateAllFromJson.(course, file_path)

    # Verify counts haven't changed (17 levels, 119 lessons total)
    assert_equal 17, Level.count
    assert_equal 119, Lesson.count

    # Verify the same records were updated, not recreated
    assert_equal level_ids, Level.pluck(:id).sort
    assert_equal lesson_ids, Lesson.pluck(:id).sort
  end

  test "slug renames update the existing records (matched by uuid)" do
    course = create(:course)

    sync!(course, [
            level_json(uuid: "level-uuid-1", slug: "old-level-slug", lessons: [
                         lesson_json(uuid: "lesson-uuid-1", slug: "old-lesson-slug")
                       ])
          ])

    level = Level.find_by!(slug: "old-level-slug")
    lesson = Lesson.find_by!(slug: "old-lesson-slug")
    user_lesson = create(:user_lesson, lesson:)

    sync!(course, [
            level_json(uuid: "level-uuid-1", slug: "new-level-slug", lessons: [
                         lesson_json(uuid: "lesson-uuid-1", slug: "new-lesson-slug")
                       ])
          ])

    # Same records renamed in place - no duplicates
    assert_equal 1, Level.count
    assert_equal 1, Lesson.count
    assert_equal "new-level-slug", level.reload.slug
    assert_equal "new-lesson-slug", lesson.reload.slug

    # User progress untouched
    assert UserLesson.exists?(user_lesson.id)
    assert_equal lesson.id, user_lesson.reload.lesson_id
  end

  test "adopts pre-uuid records by slug and stamps their uuid" do
    course = create(:course)
    level = create(:level, course:, slug: "fundamentals")
    lesson = create(:lesson, :exercise, level:, slug: "intro")

    sync!(course, [
            level_json(uuid: "canonical-level-uuid", slug: "fundamentals", lessons: [
                         lesson_json(uuid: "canonical-lesson-uuid", slug: "intro")
                       ])
          ])

    assert_equal 1, Level.count
    assert_equal 1, Lesson.count
    assert_equal "canonical-level-uuid", level.reload.uuid
    assert_equal "canonical-lesson-uuid", lesson.reload.uuid
  end

  test "moves lessons between levels without losing progress" do
    course = create(:course)
    sync!(course, [
            level_json(uuid: "level-1", slug: "level-one", lessons: [lesson_json(uuid: "lesson-1", slug: "movable")]),
            level_json(uuid: "level-2", slug: "level-two")
          ])

    lesson = Lesson.find_by!(slug: "movable")
    user_lesson = create(:user_lesson, lesson:)

    sync!(course, [
            level_json(uuid: "level-1", slug: "level-one"),
            level_json(uuid: "level-2", slug: "level-two", lessons: [lesson_json(uuid: "lesson-1", slug: "movable")])
          ])

    assert_equal 1, Lesson.count
    assert_equal "level-two", lesson.reload.level.slug
    assert UserLesson.exists?(user_lesson.id)
  end

  test "reorders levels and lessons to match JSON order" do
    course = create(:course)
    sync!(course, [
            level_json(uuid: "level-1", slug: "first", lessons: [
                         lesson_json(uuid: "lesson-a", slug: "lesson-a"),
                         lesson_json(uuid: "lesson-b", slug: "lesson-b")
                       ]),
            level_json(uuid: "level-2", slug: "second")
          ])

    # Swap level order and lesson order
    sync!(course, [
            level_json(uuid: "level-2", slug: "second"),
            level_json(uuid: "level-1", slug: "first", lessons: [
                         lesson_json(uuid: "lesson-b", slug: "lesson-b"),
                         lesson_json(uuid: "lesson-a", slug: "lesson-a")
                       ])
          ])

    assert_equal %w[second first], course.levels.reload.map(&:slug)
    assert_equal %w[lesson-b lesson-a], Level.find_by!(slug: "first").lessons.map(&:slug)
  end

  test "returns orphaned records and does not delete them" do
    course = create(:course)
    sync!(course, [
            level_json(uuid: "keep-level", slug: "keep-level", lessons: [lesson_json(uuid: "keep-lesson", slug: "keep-lesson")]),
            level_json(uuid: "orphan-level", slug: "orphan-level", lessons: [lesson_json(uuid: "orphan-lesson", slug: "orphan-lesson")])
          ])

    result = sync!(course, [
                     level_json(uuid: "keep-level", slug: "keep-level", lessons: [lesson_json(uuid: "keep-lesson", slug: "keep-lesson")])
                   ])

    assert_equal ["orphan-level"], result[:orphaned_levels]
    assert_equal ["orphan-lesson"], result[:orphaned_lessons]

    # Orphans are never deleted - they may have user progress attached
    assert Level.exists?(slug: "orphan-level")
    assert Lesson.exists?(slug: "orphan-lesson")
  end

  test "raises error for non-existent file" do
    course = create(:course)
    error = assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, "nonexistent.json")
    end

    assert_match(/File not found/, error.message)
  end

  test "raises error for invalid JSON" do
    course = create(:course)
    file = Tempfile.new(['invalid', '.json'])
    file.write("{ invalid json")
    file.close

    error = assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, file.path)
    end

    assert_match(/Invalid JSON/, error.message)
  ensure
    file.unlink
  end

  test "raises error for JSON missing levels array" do
    course = create(:course)
    file = Tempfile.new(['missing', '.json'])
    file.write('{ "something": "else" }')
    file.close

    error = assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, file.path)
    end

    assert_match(/missing 'levels' array/, error.message)
  ensure
    file.unlink
  end

  test "raises error for level missing uuid" do
    course = create(:course)

    error = assert_raises InvalidJsonError do
      sync!(course, [level_json(uuid: "level-1", slug: "valid").merge("uuid" => nil)])
    end

    assert_match(/missing required 'uuid' field/, error.message)
  end

  test "raises error for level missing required fields" do
    course = create(:course)

    error = assert_raises InvalidJsonError do
      sync!(course, [level_json(uuid: "level-1", slug: "valid").except("title")])
    end

    assert_match(/missing required 'title' field/, error.message)
  end

  test "raises error for lesson missing uuid" do
    course = create(:course)

    error = assert_raises InvalidJsonError do
      sync!(course, [
              level_json(uuid: "level-1", slug: "valid", lessons: [
                           lesson_json(uuid: "lesson-1", slug: "valid-lesson").except("uuid")
                         ])
            ])
    end

    assert_match(/Lesson missing required 'uuid' field/, error.message)
  end

  test "wraps everything in transaction - rolls back on error" do
    course = create(:course)
    create(:level, course:, slug: "existing", title: "Existing")

    assert_raises InvalidJsonError do
      sync!(course, [
              level_json(uuid: "level-1", slug: "valid-level"),
              { "uuid" => "level-2", "slug" => "invalid-level" }
            ])
    end

    # Nothing should be created or changed due to transaction rollback
    assert_equal 0, Level.where(slug: "valid-level").count
    assert_equal 1, Level.count
    assert Level.exists?(slug: "existing")
  end

  test "updates title and description on existing records" do
    course = create(:course)
    level = create(:level, course:, slug: "fundamentals", title: "Old Title", description: "Old description")

    sync!(course, [
            level_json(uuid: "level-1", slug: "fundamentals").merge("title" => "New Title", "description" => "New description")
          ])

    level.reload
    assert_equal "New Title", level.title
    assert_equal "New description", level.description
  end

  test "preserves existing records not in JSON" do
    course = create(:course)
    existing_level1 = create(:level, course:, slug: "existing-1", title: "Existing 1")
    existing_level2 = create(:level, course:, slug: "existing-2", title: "Existing 2")

    sync!(course, [level_json(uuid: "level-1", slug: "new-level")])

    # All three levels should exist
    assert_equal 3, Level.count
    assert Level.exists?(id: existing_level1.id)
    assert Level.exists?(id: existing_level2.id)
    assert Level.exists?(slug: "new-level")
  end

  private
  def sync!(course, levels)
    file = Tempfile.new(["curriculum", ".json"])
    file.write(JSON.generate({ levels: }))
    file.close

    Level::CreateAllFromJson.(course, file.path)
  ensure
    file.unlink
  end

  def level_json(uuid:, slug:, lessons: [])
    {
      "uuid" => uuid,
      "slug" => slug,
      "title" => slug.titleize,
      "description" => "Description for #{slug}",
      "milestone_summary" => "Summary for #{slug}",
      "milestone_content" => "# Content for #{slug}",
      "lessons" => lessons
    }
  end

  def lesson_json(uuid:, slug:)
    {
      "uuid" => uuid,
      "slug" => slug,
      "title" => slug.titleize,
      "description" => "Description for #{slug}",
      "type" => "exercise",
      "data" => { "slug" => slug }
    }
  end
end
