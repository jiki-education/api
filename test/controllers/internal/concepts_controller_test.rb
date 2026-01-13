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
    assert_json_response({
      results: SerializeConcepts.([concept_1, concept_3]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
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
    # Results ordered alphabetically by title
    assert_json_response({
      results: SerializeConcepts.([concept_3, concept_1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index title filter only returns unlocked concepts" do
    Prosopite.finish
    concept_1 = create(:concept, title: "String Basics")
    create(:concept, title: "String Advanced")

    Concept::UnlockForUser.(concept_1, @current_user)
    # concept_2 is locked

    get internal_concepts_path(title: "String"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeConcepts.([concept_1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index filters by slugs parameter" do
    Prosopite.finish
    concept_1 = create(:concept, title: "Arrays", slug: "arrays")
    concept_2 = create(:concept, title: "Hashes", slug: "hashes")
    create(:concept, title: "Strings", slug: "strings")

    Concept::UnlockForUser.(concept_1, @current_user)
    Concept::UnlockForUser.(concept_2, @current_user)

    get internal_concepts_path(slugs: "arrays,hashes"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeConcepts.([concept_1, concept_2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index slugs filter only returns unlocked concepts" do
    Prosopite.finish
    concept_1 = create(:concept, title: "Arrays", slug: "arrays")
    create(:concept, title: "Hashes", slug: "hashes")

    Concept::UnlockForUser.(concept_1, @current_user)
    # concept_2 is locked

    get internal_concepts_path(slugs: "arrays,hashes"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeConcepts.([concept_1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    concept_1 = create(:concept, title: "Concept A")
    concept_2 = create(:concept, title: "Concept B")
    concept_3 = create(:concept, title: "Concept C")

    Concept::UnlockForUser.(concept_1, @current_user)
    Concept::UnlockForUser.(concept_2, @current_user)
    Concept::UnlockForUser.(concept_3, @current_user)

    get internal_concepts_path(page: 1, per: 2), headers: @headers, as: :json

    assert_response :success
    # Ordered alphabetically by title: A, B (first page)
    assert_json_response({
      results: SerializeConcepts.([concept_1, concept_2]),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3,
        events: []
      }
    })
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    concepts = Array.new(5) { |i| create(:concept, title: "Concept #{i}").tap { |c| Concept::UnlockForUser.(c, @current_user) } }

    get internal_concepts_path(per: 3), headers: @headers, as: :json

    assert_response :success
    # Ordered alphabetically by title: Concept 0, 1, 2
    assert_json_response({
      results: SerializeConcepts.([concepts[0], concepts[1], concepts[2]]),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 5,
        events: []
      }
    })
  end

  test "GET index returns empty array when user has no unlocked concepts" do
    create(:concept)
    create(:concept)

    get internal_concepts_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: [],
      meta: {
        current_page: 1,
        total_pages: 0,
        total_count: 0,
        events: []
      }
    })
  end

  # GET /v1/concepts/:slug (show) tests
  test "GET show returns unlocked concept with full details" do
    concept = create(:concept, title: "Arrays")
    Concept::UnlockForUser.(concept, @current_user)

    get internal_concept_path(concept_slug: concept.slug, as: :json), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      concept: SerializeConcept.(concept)
    })
  end

  test "GET show returns 403 for locked concept" do
    concept = create(:concept, title: "Arrays")
    # Not unlocked for user

    get internal_concept_path(concept_slug: concept.slug, as: :json), headers: @headers, as: :json

    assert_response :forbidden
    assert_json_response({
      error: "This concept is locked"
    })
  end

  test "GET show returns 404 for non-existent concept" do
    get internal_concept_path(concept_slug: "non-existent-slug"), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Concept not found"
      }
    })
  end

  test "GET show works with slug history" do
    concept = create(:concept, slug: "original-slug")
    Concept::UnlockForUser.(concept, @current_user)

    # Change the slug
    concept.update!(slug: "new-slug")

    # Old slug should still work
    get internal_concept_path(concept_slug: "original-slug"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      concept: SerializeConcept.(concept)
    })
  end

  test "GET show for old slug still respects lock status" do
    concept = create(:concept, slug: "original-slug")
    # Not unlocked for user

    concept.update!(slug: "new-slug")

    get internal_concept_path(concept_slug: "original-slug"), headers: @headers, as: :json

    assert_response :forbidden
    assert_json_response({
      error: "This concept is locked"
    })
  end
end
