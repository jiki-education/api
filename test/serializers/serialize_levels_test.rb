require "test_helper"

class SerializeLevelsTest < ActiveSupport::TestCase
  test "serializes multiple levels with their lessons" do
    level1 = create(:level, slug: "level-1")
    level2 = create(:level, slug: "level-2")
    create(:lesson, :exercise, level: level1, slug: "l1")
    create(:lesson, :video, level: level2, slug: "l2")

    expected = [
      {
        slug: "level-1",
        lessons: [{ slug: "l1", type: "exercise", walkthrough_video_data: nil }]
      },
      {
        slug: "level-2",
        lessons: [{ slug: "l2", type: "video", walkthrough_video_data: nil }]
      }
    ]

    assert_equal(expected, SerializeLevels.([level1, level2]))
  end

  test "returns empty array for no levels" do
    assert_empty SerializeLevels.([])
  end

  test "serializes single level" do
    level = create(:level, slug: "solo")
    create(:lesson, :exercise, level: level, slug: "lesson-solo")

    expected = [
      {
        slug: "solo",
        lessons: [{ slug: "lesson-solo", type: "exercise", walkthrough_video_data: nil }]
      }
    ]
    assert_equal(expected, SerializeLevels.([level]))
  end

  # The milestone screen this fed was removed - the front end renders it
  # from its own next-intl catalogue and never read this field.
  test "does not include milestone_summary" do
    level = create(:level, slug: "level-1")

    refute SerializeLevels.([level])[0].key?(:milestone_summary)
  end

  # Lesson copy is authored in the front-end curriculum repo, per locale.
  test "lessons carry no title or description" do
    level = create(:level, slug: "level-1")
    create(:lesson, :exercise, level:, slug: "l1")

    lesson = SerializeLevels.([level])[0][:lessons][0]

    refute lesson.key?(:title)
    refute lesson.key?(:description)
  end
end
