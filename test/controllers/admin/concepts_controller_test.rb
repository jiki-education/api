require "test_helper"

class Admin::ConceptsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_concepts_path, method: :get
  guard_admin! :admin_concepts_path, method: :post
  guard_admin! :admin_concept_path, args: [1], method: :get
  guard_admin! :admin_concept_path, args: [1], method: :patch
  guard_admin! :admin_concept_path, args: [1], method: :delete

  # INDEX tests

  test "GET index returns all concepts with pagination" do
    Prosopite.finish # Stop scan before creating test data
    concept1 = create(:concept, title: "Strings", slug: "strings")
    concept2 = create(:concept, title: "Arrays", slug: "arrays")

    Prosopite.scan # Resume scan for the actual request
    get admin_concepts_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminConcepts.([concept2, concept1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  test "GET index filters by title" do
    Prosopite.finish
    concept1 = create(:concept)
    concept1.update!(title: "Strings and Text")
    concept2 = create(:concept)
    concept2.update!(title: "Arrays")

    Prosopite.scan
    get admin_concepts_path(title: "String"), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminConcepts.([concept1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1
      }
    })
  end

  test "GET index supports pagination" do
    Prosopite.finish
    concept1 = create(:concept, title: "Concept 1")
    concept2 = create(:concept, title: "Concept 2")
    create(:concept, title: "Concept 3")

    Prosopite.scan
    get admin_concepts_path(page: 1, per: 2), as: :json

    assert_response :success
    # Ordered alphabetically by title
    assert_json_response({
      results: SerializeAdminConcepts.([concept1, concept2]),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3
      }
    })
  end

  test "GET index returns empty results when no concepts exist" do
    get admin_concepts_path, as: :json

    assert_response :success
    assert_json_response({
      results: [],
      meta: {
        current_page: 1,
        total_pages: 0,
        total_count: 0
      }
    })
  end

  # CREATE tests

  test "POST create creates concept with valid attributes" do
    concept_params = {
      concept: {
        title: "Strings",
        slug: "strings",
        description: "Learn about strings",
        content_markdown: "# Strings\n\nText content"
      }
    }

    assert_difference "Concept.count", 1 do
      post admin_concepts_path, params: concept_params, as: :json
    end

    assert_response :created

    concept = Concept.last
    assert_json_response({
      concept: SerializeAdminConcept.(concept)
    })
  end

  test "POST create with video providers" do
    concept_params = {
      concept: {
        title: "Strings",
        description: "Learn about strings",
        content_markdown: "# Strings",
        standard_video_provider: "youtube",
        standard_video_id: "abc123",
        premium_video_provider: "mux",
        premium_video_id: "def456"
      }
    }

    post admin_concepts_path, params: concept_params, as: :json

    assert_response :created

    concept = Concept.last
    assert_json_response({
      concept: SerializeAdminConcept.(concept)
    })
  end

  test "POST create returns validation error for invalid attributes" do
    concept_params = {
      concept: {
        title: ""
      }
    }

    assert_no_difference "Concept.count" do
      post admin_concepts_path, params: concept_params, as: :json
    end

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: /Validation failed/
      }
    })
  end

  # SHOW tests

  test "GET show returns concept with markdown" do
    concept = create(:concept, title: "Strings", content_markdown: "# Strings\n\nContent")

    get admin_concept_path(concept.id), as: :json

    assert_response :success
    assert_json_response({
      concept: SerializeAdminConcept.(concept)
    })
  end

  test "GET show returns 404 for non-existent concept" do
    get admin_concept_path(999_999), as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Concept not found"
      }
    })
  end

  # UPDATE tests

  test "PATCH update updates concept with valid attributes" do
    concept = create(:concept, title: "Original")
    update_params = {
      concept: {
        title: "Updated"
      }
    }

    patch admin_concept_path(concept.id), params: update_params, as: :json

    assert_response :success

    concept.reload
    assert_json_response({
      concept: SerializeAdminConcept.(concept)
    })
  end

  test "PATCH update updates markdown and regenerates HTML" do
    concept = create(:concept, content_markdown: "# Original")
    update_params = {
      concept: {
        content_markdown: "# Updated"
      }
    }

    patch admin_concept_path(concept.id), params: update_params, as: :json

    assert_response :success
    assert_equal "# Updated", concept.reload.content_markdown
    assert_includes concept.content_html, "Updated"
  end

  test "PATCH update returns validation error for invalid attributes" do
    concept = create(:concept)
    update_params = {
      concept: {
        title: ""
      }
    }

    patch admin_concept_path(concept.id), params: update_params, as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: /Validation failed/
      }
    })
  end

  test "PATCH update returns 404 for non-existent concept" do
    update_params = {
      concept: {
        title: "Updated"
      }
    }

    patch admin_concept_path(999_999), params: update_params, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Concept not found"
      }
    })
  end

  # DESTROY tests

  test "DELETE destroy deletes concept" do
    concept = create(:concept)

    assert_difference "Concept.count", -1 do
      delete admin_concept_path(concept.id), as: :json
    end

    assert_response :no_content
  end

  test "DELETE destroy returns 404 for non-existent concept" do
    delete admin_concept_path(999_999), as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Concept not found"
      }
    })
  end

  # Parent-child hierarchy tests

  test "POST create with parent_concept_id" do
    parent = create(:concept)
    concept_params = {
      concept: {
        title: "Child Concept",
        description: "A child concept",
        content_markdown: "# Child",
        parent_concept_id: parent.id
      }
    }

    post admin_concepts_path, params: concept_params, as: :json

    assert_response :created
    concept = Concept.last
    assert_equal parent.id, concept.parent_concept_id
  end

  test "PATCH update parent_concept_id" do
    parent = create(:concept)
    concept = create(:concept)
    update_params = {
      concept: {
        parent_concept_id: parent.id
      }
    }

    patch admin_concept_path(concept.id), params: update_params, as: :json

    assert_response :success
    assert_equal parent.id, concept.reload.parent_concept_id
  end

  test "PATCH update returns validation error for circular reference" do
    parent = create(:concept)
    child = create(:concept, parent: parent)
    update_params = {
      concept: {
        parent_concept_id: child.id
      }
    }

    patch admin_concept_path(parent.id), params: update_params, as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: /circular reference/
      }
    })
  end

  test "GET show includes ancestors and children_count" do
    Prosopite.finish
    grandparent = create(:concept, title: "Grandparent")
    parent = create(:concept, title: "Parent", parent: grandparent)
    concept = create(:concept, title: "Concept", parent: parent)
    create(:concept, parent: concept) # child

    Prosopite.scan
    get admin_concept_path(concept.id), as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal 1, response_data["concept"]["children_count"]
    assert_equal 2, response_data["concept"]["ancestors"].length
    assert_equal grandparent.slug, response_data["concept"]["ancestors"][0]["slug"]
    assert_equal parent.slug, response_data["concept"]["ancestors"][1]["slug"]
  end

  test "GET index includes children_count" do
    Prosopite.finish
    parent = create(:concept, title: "Parent")
    create(:concept, parent: parent)
    create(:concept, parent: parent)

    Prosopite.scan
    get admin_concepts_path, as: :json

    assert_response :success
    response_data = JSON.parse(response.body)
    parent_result = response_data["results"].find { |c| c["title"] == "Parent" }
    assert_equal 2, parent_result["children_count"]
  end
end
