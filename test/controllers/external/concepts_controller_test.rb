require "test_helper"

class External::ConceptsControllerTest < ActionDispatch::IntegrationTest
  test "GET index returns all concepts without authentication" do
    Prosopite.finish
    create(:concept, title: "Arrays")
    create(:concept, title: "Strings")

    get external_concepts_path, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
  end

  test "GET index does not filter by user unlock status" do
    Prosopite.finish
    concept_1 = create(:concept, title: "Arrays")
    create(:concept, title: "Strings")

    # Even if we had a user with unlocked concepts, external endpoint shows all
    user = create(:user)
    Concept::UnlockForUser.(concept_1, user)
    # concept_2 remains locked for this user

    get external_concepts_path, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    # Both concepts should be returned
    assert_equal 2, response_json[:results].size
  end

  test "GET show returns any concept without authentication" do
    concept = create(:concept, title: "Arrays", description: "Learn about arrays")

    get external_concept_path(concept.slug), as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal "Arrays", response_json[:concept][:title]
    assert_equal concept.slug, response_json[:concept][:slug]
  end

  test "GET show returns 404 for non-existent concept" do
    get external_concept_path(concept_slug: "non-existent-slug"), as: :json

    assert_response :not_found
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal "Concept not found", response_json[:error][:message]
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    create(:concept, title: "String Basics")
    create(:concept, title: "Arrays")
    create(:concept, title: "String Advanced")

    get external_concepts_path(title: "String"), as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    titles = response_json[:results].map { |c| c[:title] }
    assert_includes titles, "String Basics"
    assert_includes titles, "String Advanced"
    refute_includes titles, "Arrays"
  end
end
