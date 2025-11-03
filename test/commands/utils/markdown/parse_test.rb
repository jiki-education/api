require "test_helper"

class Utils::Markdown::ParseTest < ActiveSupport::TestCase
  test "converts markdown to HTML" do
    markdown = "# Hello World\n\nThis is a paragraph."
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<h1"
    assert_includes html, "Hello World"
    assert_includes html, "<p"
    assert_includes html, "This is a paragraph"
  end

  test "returns empty string for blank text" do
    assert_equal "", Utils::Markdown::Parse.(nil)
    assert_equal "", Utils::Markdown::Parse.("")
  end

  test "handles code blocks" do
    markdown = "```ruby\ndef hello\n  puts 'world'\nend\n```"
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<pre"
    assert_includes html, "<code"
    assert_includes html, "hello"
    assert_includes html, "world"
  end

  test "handles lists" do
    markdown = "- Item 1\n- Item 2\n- Item 3"
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<ul"
    assert_includes html, "<li"
    assert_includes html, "Item 1"
  end

  test "handles links" do
    markdown = "[Click here](https://example.com)"
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<a"
    assert_includes html, "href"
    assert_includes html, "https://example.com"
    assert_includes html, "Click here"
  end

  test "sanitizes HTML comments" do
    markdown = "<!-- This is a comment -->\n# Hello"
    html = Utils::Markdown::Parse.(markdown)

    refute_includes html, "This is a comment"
    refute_includes html, "<!--"
  end

  test "handles emphasis and strong" do
    markdown = "*italic* and **bold**"
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<em"
    assert_includes html, "italic"
    assert_includes html, "<strong"
    assert_includes html, "bold"
  end

  test "handles blockquotes" do
    markdown = "> This is a quote"
    html = Utils::Markdown::Parse.(markdown)

    assert_includes html, "<blockquote"
    assert_includes html, "This is a quote"
  end
end
