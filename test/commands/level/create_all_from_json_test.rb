require "test_helper"

class Level::CreateAllFromJsonTest < ActiveSupport::TestCase
  test "imports levels and lessons from valid JSON" do
    course = create(:course)
    file_path = Rails.root.join("db", "seeds", "curriculum.json")

    result = Level::CreateAllFromJson.(course, file_path.to_s)

    assert result

    # Verify levels were created
    using_functions = Level.find_by(slug: "using-functions")
    assert using_functions
    assert_equal "Using Functions", using_functions.title
    assert_equal 1, using_functions.position
    assert_equal course, using_functions.course

    strings_and_colors = Level.find_by(slug: "strings-and-colors")
    assert strings_and_colors
    assert_equal "Strings and Colors", strings_and_colors.title
    assert_equal 2, strings_and_colors.position

    # Verify lessons were created
    assert_equal 7, using_functions.lessons.count
    first_lesson = using_functions.lessons.find_by(slug: "maze-solve-basic")
    assert first_lesson
    assert_equal "Solve the Maze", first_lesson.title
    assert_equal "exercise", first_lesson.type
    assert_equal({ slug: "maze-solve-basic" }, first_lesson.data)
    assert_equal 2, first_lesson.position
  end

  test "is idempotent - running twice updates existing records" do
    course = create(:course)
    file_path = Rails.root.join("db", "seeds", "curriculum.json")

    # First run
    Level::CreateAllFromJson.(course, file_path.to_s)

    # Second run
    Level::CreateAllFromJson.(course, file_path.to_s)

    # Verify counts haven't changed (5 levels, 25 lessons total: 7 + 5 + 3 + 4 + 6)
    assert_equal 5, Level.count
    assert_equal 25, Lesson.count
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

  test "raises error for level missing required fields" do
    course = create(:course)
    file = Tempfile.new(['missing_fields', '.json'])
    file.write('{ "levels": [{ "slug": "test" }] }')
    file.close

    error = assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, file.path)
    end

    assert_match(/missing required 'title' field/, error.message)
  ensure
    file.unlink
  end

  test "wraps everything in transaction - rolls back on error" do
    course = create(:course)
    file = Tempfile.new(['partial', '.json'])
    file.write('{
      "levels": [
        {
          "slug": "valid-level",
          "title": "Valid Level",
          "description": "This is valid",
          "lessons": []
        },
        {
          "slug": "invalid-level"
        }
      ]
    }')
    file.close

    assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, file.path)
    end

    # Nothing should be created due to transaction rollback
    assert_equal 0, Level.where(slug: "valid-level").count
  ensure
    file.unlink
  end

  test "updates title and description on existing records" do
    course = create(:course)
    # Create initial level
    level = create(:level, course:, slug: "fundamentals", title: "Old Title", description: "Old description")

    file = Tempfile.new(['update', '.json'])
    file.write('{
      "levels": [{
        "slug": "fundamentals",
        "title": "New Title",
        "description": "New description",
        "milestone_summary": "Great job!",
        "milestone_content": "# Congratulations!",
        "lessons": []
      }]
    }')
    file.close

    Level::CreateAllFromJson.(course, file.path)

    level.reload
    assert_equal "New Title", level.title
    assert_equal "New description", level.description
  ensure
    file.unlink
  end

  test "delete_existing: false (default) preserves existing records not in JSON" do
    course = create(:course)
    # Create some existing levels
    existing_level1 = create(:level, course:, slug: "existing-1", title: "Existing 1")
    existing_level2 = create(:level, course:, slug: "existing-2", title: "Existing 2")

    file = Tempfile.new(['new', '.json'])
    file.write('{
      "levels": [{
        "slug": "new-level",
        "title": "New Level",
        "description": "This is a new level",
        "milestone_summary": "Great job!",
        "milestone_content": "# Congratulations!",
        "lessons": []
      }]
    }')
    file.close

    Level::CreateAllFromJson.(course, file.path, delete_existing: false)

    # All three levels should exist
    assert_equal 3, Level.count
    assert Level.exists?(id: existing_level1.id)
    assert Level.exists?(id: existing_level2.id)
    assert Level.exists?(slug: "new-level")
  ensure
    file.unlink
  end

  test "delete_existing: true removes all existing levels before import" do
    course = create(:course)
    # Create some existing levels with lessons
    existing_level1 = create(:level, course:, slug: "existing-1", title: "Existing 1")
    create(:lesson, :exercise, level: existing_level1, slug: "existing-lesson-1", title: "Existing Lesson 1")
    create(:level, course:, slug: "existing-2", title: "Existing 2")

    file = Tempfile.new(['clean', '.json'])
    file.write('{
      "levels": [{
        "slug": "new-level",
        "title": "New Level",
        "description": "This is a new level",
        "milestone_summary": "Great job!",
        "milestone_content": "# Congratulations!",
        "lessons": []
      }]
    }')
    file.close

    Level::CreateAllFromJson.(course, file.path, delete_existing: true)

    # Only the new level should exist
    assert_equal 1, Level.count
    refute Level.exists?(slug: "existing-1")
    refute Level.exists?(slug: "existing-2")
    assert Level.exists?(slug: "new-level")

    # Lessons should also be deleted (cascade)
    assert_equal 0, Lesson.where(slug: "existing-lesson-1").count
  ensure
    file.unlink
  end

  test "delete_existing: true with idempotent behavior" do
    course = create(:course)
    file = Tempfile.new(['idempotent', '.json'])
    file.write('{
      "levels": [{
        "slug": "level-1",
        "title": "Level 1",
        "description": "First level",
        "milestone_summary": "Great job!",
        "milestone_content": "# Congratulations!",
        "lessons": []
      }]
    }')
    file.close

    # First import
    Level::CreateAllFromJson.(course, file.path, delete_existing: true)
    assert_equal 1, Level.count
    first_level_id = Level.find_by(slug: "level-1").id

    # Second import - should delete and recreate
    Level::CreateAllFromJson.(course, file.path, delete_existing: true)
    assert_equal 1, Level.count

    # ID should be different because it was deleted and recreated
    second_level_id = Level.find_by(slug: "level-1").id
    refute_equal first_level_id, second_level_id
  ensure
    file.unlink
  end

  test "delete_existing: true handles transaction rollback correctly" do
    course = create(:course)
    # Create existing data
    create(:level, course:, slug: "existing", title: "Existing")

    file = Tempfile.new(['invalid_partial', '.json'])
    file.write('{
      "levels": [
        {
          "slug": "valid-level",
          "title": "Valid Level",
          "description": "This is valid",
          "milestone_summary": "Great job!",
          "milestone_content": "# Congratulations!",
          "lessons": []
        },
        {
          "slug": "invalid-level"
        }
      ]
    }')
    file.close

    assert_raises InvalidJsonError do
      Level::CreateAllFromJson.(course, file.path, delete_existing: true)
    end

    # Existing level should be preserved (deletion happens inside transaction)
    assert_equal 1, Level.count
    assert Level.exists?(slug: "existing")
  ensure
    file.unlink
  end
end
