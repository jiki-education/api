require "test_helper"

class EmailTemplate::GenerateSummaryTest < ActiveSupport::TestCase
  test "returns empty array when no templates exist" do
    result = EmailTemplate::GenerateSummary.()

    assert_empty result
  end

  test "returns summary with single template" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    result = EmailTemplate::GenerateSummary.()

    assert_equal 1, result.length
    assert_equal "level_completion", result[0][:type]
    assert_equal "level-1", result[0][:slug]
    assert_equal ["en"], result[0][:locales]
  end

  test "groups templates by type and slug with multiple locales" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "hu")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "fr")

    result = EmailTemplate::GenerateSummary.()

    assert_equal 1, result.length
    assert_equal "level_completion", result[0][:type]
    assert_equal "level-1", result[0][:slug]
    assert_equal %w[en fr hu], result[0][:locales]
  end

  test "returns separate entries for different slugs" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    create(:email_template, type: :level_completion, slug: "level-2", locale: "en")
    create(:email_template, type: :level_completion, slug: "level-2", locale: "hu")

    result = EmailTemplate::GenerateSummary.()

    assert_equal 2, result.length

    level_1 = result.find { |r| r[:slug] == "level-1" }
    assert_equal "level_completion", level_1[:type]
    assert_equal ["en"], level_1[:locales]

    level_2 = result.find { |r| r[:slug] == "level-2" }
    assert_equal "level_completion", level_2[:type]
    assert_equal %w[en hu], level_2[:locales]
  end

  test "sorts locales alphabetically within each group" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "hu")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "fr")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    result = EmailTemplate::GenerateSummary.()

    assert_equal 1, result.length
    assert_equal %w[en fr hu], result[0][:locales]
  end

  test "orders results by type and slug" do
    create(:email_template, type: :level_completion, slug: "level-2", locale: "en")
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    result = EmailTemplate::GenerateSummary.()

    assert_equal 2, result.length
    assert_equal "level-1", result[0][:slug]
    assert_equal "level-2", result[1][:slug]
  end
end
