require "test_helper"

class ExerciseSubmission::CountLinesOfCodeTest < ActiveSupport::TestCase
  test "counts javascript lines" do
    source = <<~JS
      function isEven(n) {
        return n % 2 === 0;
      }
    JS

    assert_equal 3, ExerciseSubmission::CountLinesOfCode.(source, "javascript")
  end

  test "ignores blank lines" do
    source = "let a = 1;\n\n\nlet b = 2;\n"

    assert_equal 2, ExerciseSubmission::CountLinesOfCode.(source, "javascript")
  end

  test "ignores javascript line comments" do
    source = "// a comment\nlet a = 1;\n  // an indented comment\n"

    assert_equal 1, ExerciseSubmission::CountLinesOfCode.(source, "javascript")
  end

  test "ignores javascript block comments" do
    source = "/*\n a block\n comment\n*/\nlet a = 1;\n"

    assert_equal 1, ExerciseSubmission::CountLinesOfCode.(source, "javascript")
  end

  test "counts a closing brace followed by else as one line" do
    split = "if (a) {\n  b();\n}\nelse {\n  c();\n}\n"
    joined = "if (a) {\n  b();\n} else {\n  c();\n}\n"

    assert_equal ExerciseSubmission::CountLinesOfCode.(joined, "javascript"),
      ExerciseSubmission::CountLinesOfCode.(split, "javascript")
  end

  test "counts a trailing closing brace" do
    source = "function a() {\n  b();\n}\n"

    assert_equal 3, ExerciseSubmission::CountLinesOfCode.(source, "javascript")
  end

  test "counts python lines" do
    source = <<~PY
      def is_even(n):
          return n % 2 == 0
    PY

    assert_equal 2, ExerciseSubmission::CountLinesOfCode.(source, "python")
  end

  test "ignores python comments and blank lines" do
    source = "# a comment\n\nx = 1\n    # indented comment\ny = 2\n"

    assert_equal 2, ExerciseSubmission::CountLinesOfCode.(source, "python")
  end

  test "does not treat a python hash inside a string as a comment marker mid-line" do
    source = "x = \"#hashtag\"\n"

    assert_equal 1, ExerciseSubmission::CountLinesOfCode.(source, "python")
  end

  test "handles an empty source" do
    assert_equal 0, ExerciseSubmission::CountLinesOfCode.("", "javascript")
    assert_equal 0, ExerciseSubmission::CountLinesOfCode.("", "python")
  end
end
