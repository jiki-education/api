require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "preview_from strips markdown syntax" do
    markdown = "# You Did It! 🎉\n\nYou've **finished** all lessons in [this level](https://jiki.io)."

    assert_equal "You Did It! 🎉 You've finished all lessons in this level.", preview_from(markdown)
  end

  test "preview_from truncates to the word limit with an ellipsis" do
    markdown = (1..40).map { |i| "word#{i}" }.join(' ')

    preview = preview_from(markdown)

    assert_equal "word#{ApplicationMailer::PREVIEW_WORD_LIMIT}…", preview.split.last
    assert_equal ApplicationMailer::PREVIEW_WORD_LIMIT, preview.split.length
  end

  test "preview_from leaves short bodies unabridged" do
    assert_equal "Short and sweet.", preview_from("Short and sweet.")
  end

  test "preview_from handles blank content" do
    assert_equal "", preview_from(nil)
    assert_equal "", preview_from("")
  end

  private
  def preview_from(markdown) = ApplicationMailer.new.send(:preview_from, markdown)
end
