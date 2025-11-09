require "test_helper"

class EmailTemplate::SearchTest < ActiveSupport::TestCase
  test "no options returns all email templates paginated" do
    template_1 = create :email_template
    template_2 = create :email_template, slug: "another-slug"

    result = EmailTemplate::Search.()

    assert_equal [template_1, template_2], result.to_a
  end

  test "type: filters by exact type match" do
    template_1 = create :email_template, type: :level_completion

    assert_equal [template_1], EmailTemplate::Search.(type: :level_completion).to_a
    assert_equal [template_1], EmailTemplate::Search.(type: "level_completion").to_a
    assert_equal [template_1], EmailTemplate::Search.(type: "").to_a
  end

  test "slug: search for partial slug match" do
    template_1 = create :email_template, slug: "welcome-email"
    template_2 = create :email_template, slug: "goodbye-email"
    template_3 = create :email_template, slug: "weekly-update"

    assert_equal [template_1, template_2, template_3], EmailTemplate::Search.(slug: "").to_a
    assert_equal [template_1, template_2], EmailTemplate::Search.(slug: "email").to_a
    assert_equal [template_1], EmailTemplate::Search.(slug: "welcome").to_a
    assert_empty EmailTemplate::Search.(slug: "xyz").to_a
  end

  test "locale: filters by exact locale match" do
    template_1 = create :email_template, locale: "en"
    template_2 = create :email_template, slug: "test-2", locale: "hu"
    template_3 = create :email_template, slug: "test-3", locale: "en"

    assert_equal [template_1, template_2, template_3], EmailTemplate::Search.(locale: "").to_a
    assert_equal [template_1, template_3], EmailTemplate::Search.(locale: "en").to_a
    assert_equal [template_2], EmailTemplate::Search.(locale: "hu").to_a
    assert_empty EmailTemplate::Search.(locale: "de").to_a
  end

  test "pagination" do
    template_1 = create :email_template
    template_2 = create :email_template, slug: "second"

    assert_equal [template_1], EmailTemplate::Search.(page: 1, per: 1).to_a
    assert_equal [template_2], EmailTemplate::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    5.times { |i| create :email_template, slug: "template-#{i}" }

    result = EmailTemplate::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "combines multiple filters" do
    template_1 = create :email_template, type: :level_completion, slug: "level-1", locale: "en"
    create :email_template, type: :level_completion, slug: "level-2", locale: "hu"
    create :email_template, type: :level_completion, slug: "other", locale: "en"

    result = EmailTemplate::Search.(slug: "level", locale: "en")

    assert_equal [template_1], result.to_a
  end
end
