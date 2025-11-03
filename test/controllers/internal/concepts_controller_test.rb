require "test_helper"

class Internal::ConceptsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_concepts_path, method: :get
  guard_incorrect_token! :internal_concept_path, args: ["some-concept"], method: :get

  # GET /v1/concepts (index) tests
  test "GET index returns unlocked concepts by default (scoped)" do
    Prosopite.finish
    concept_1 = create(:concept, title: "Arrays")
    create(:concept, title: "Strings")
    concept_3 = create(:concept, title: "Hashes")

    Concept::UnlockForUser.(concept_1, @current_user)
    Concept::UnlockForUser.(concept_3, @current_user)

    get internal_concepts_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    assert_equal "Arrays", response_json[:results][0][:title]
    assert_equal "Hashes", response_json[:results][1][:title]

    # Verify fields returned (no id, no content_html in collection)
    result = response_json[:results][0]
    refute_includes result.keys, :id
    refute_includes result.keys, :content_html
    assert_includes result.keys, :title
    assert_includes result.keys, :slug
    assert_includes result.keys, :description
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    concept_1 = create(:concept, title: "String Basics")
    concept_2 = create(:concept, title: "Arrays")
    concept_3 = create(:concept, title: "String Advanced")

    Concept::UnlockForUser.(concept_1, @current_user)
    Concept::UnlockForUser.(concept_2, @current_user)
    Concept::UnlockForUser.(concept_3, @current_user)

    get internal_concepts_path(title: "String"), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    # Results ordered alphabetically by title
    assert_equal "String Advanced", response_json[:results][0][:title]
    assert_equal "String Basics", response_json[:results][1][:title]
  end

  test "GET index title filter only returns unlocked concepts" do
    Prosopite.finish
    concept_1 = create(:concept, title: "String Basics")
    create(:concept, title: "String Advanced")

    Concept::UnlockForUser.(concept_1, @current_user)
    # concept_2 is locked

    get internal_concepts_path(title: "String"), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 1, response_json[:results].size
    assert_equal "String Basics", response_json[:results][0][:title]
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    concept_1 = create(:concept)
    concept_2 = create(:concept)
    concept_3 = create(:concept)

    Concept::UnlockForUser.(concept_1, @current_user)
    Concept::UnlockForUser.(concept_2, @current_user)
    Concept::UnlockForUser.(concept_3, @current_user)

    get internal_concepts_path(page: 1, per: 2), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    assert_equal 1, response_json[:meta][:current_page]
    assert_equal 3, response_json[:meta][:total_count]
    assert_equal 2, response_json[:meta][:total_pages]
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    5.times { |_i| Concept::UnlockForUser.(create(:concept), @current_user) }

    get internal_concepts_path(per: 3), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 3, response_json[:results].size
  end

  test "GET index returns empty array when user has no unlocked concepts" do
    create(:concept)
    create(:concept)

    get internal_concepts_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 0, response_json[:results].size
  end

  # GET /v1/concepts/:slug (show) tests
  test "GET show returns unlocked concept with full details" do
    concept = create(:concept, title: "Arrays")
    Concept::UnlockForUser.(concept, @current_user)

    get internal_concept_path(concept_slug: concept.slug, as: :json), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal "Arrays", response_json[:concept][:title]
    assert_equal concept.slug, response_json[:concept][:slug]

    # Verify fields returned (no id, includes content_html in single)
    result = response_json[:concept]
    refute_includes result.keys, :id
    assert_includes result.keys, :content_html
    assert_includes result.keys, :title
    assert_includes result.keys, :slug
    assert_includes result.keys, :description
    assert_includes result.keys, :standard_video_provider
    assert_includes result.keys, :standard_video_id
    assert_includes result.keys, :premium_video_provider
    assert_includes result.keys, :premium_video_id
  end

  test "GET show returns 403 for locked concept" do
    concept = create(:concept, title: "Arrays")
    # Not unlocked for user

    get internal_concept_path(concept_slug: concept.slug, as: :json), headers: @headers, as: :json

    assert_response :forbidden
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal "This concept is locked", response_json[:error]
  end

  test "GET show returns 404 for non-existent concept" do
    get internal_concept_path(concept_slug: "non-existent-slug"), headers: @headers, as: :json

    assert_response :not_found
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal "Concept not found", response_json[:error][:message]
  end

  test "GET show works with slug history" do
    concept = create(:concept, slug: "original-slug")
    Concept::UnlockForUser.(concept, @current_user)

    # Change the slug
    concept.update!(slug: "new-slug")

    # Old slug should still work
    get internal_concept_path(concept_slug: "original-slug"), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal concept.title, response_json[:concept][:title]
  end

  test "GET show for old slug still respects lock status" do
    concept = create(:concept, slug: "original-slug")
    # Not unlocked for user

    concept.update!(slug: "new-slug")

    get internal_concept_path(concept_slug: "original-slug"), headers: @headers, as: :json

    assert_response :forbidden
  end
end
