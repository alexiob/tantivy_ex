defmodule TantivyExRemoveLongTest do
  use ExUnit.Case, async: true
  alias TantivyEx.{Native, Tokenizer}

  setup do
    # Register default tokenizers for the tests
    Native.register_default_tokenizers()
    :ok
  end

  describe "remove_long_threshold parameter" do
    test "remove_long_threshold accepts integer or nil" do
      # Test that remove_long_threshold accepts a threshold value
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "test_remove_long_40",
                 "simple",
                 true,
                 nil,
                 nil,
                 40
               )

      # Test that remove_long_threshold accepts nil (disabled)
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "test_remove_long_disabled",
                 "simple",
                 true,
                 nil,
                 nil,
                 nil
               )

      # Test custom threshold
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "test_remove_long_custom",
                 "simple",
                 true,
                 nil,
                 nil,
                 25
               )
    end

    test "remove_long_threshold=40 filters words of 40+ characters" do
      # Register tokenizer with remove_long enabled at 40 character threshold
      Tokenizer.register_text_analyzer(
        "test_long_words_enabled",
        "simple",
        true,
        nil,
        nil,
        40
      )

      # Test text with words of various lengths (avoiding underscores which tokenize)
      # 39 chars - should be kept
      # 40 chars - should be filtered
      # 41 chars - should be filtered
      test_text =
        "short medium " <>
          String.duplicate("a", 39) <>
          " " <>
          String.duplicate("b", 40) <>
          " " <>
          String.duplicate("c", 41)

      tokens = Tokenizer.tokenize_text("test_long_words_enabled", test_text)

      # Extract just the text values (tokenize_text returns a list of strings)
      token_texts = tokens

      # Words ≤ 39 chars should be present
      assert "short" in token_texts
      assert "medium" in token_texts
      # 39 chars - should be kept
      assert String.duplicate("a", 39) in token_texts

      # Words ≥ 40 chars should be filtered out
      # 40 chars - should be filtered
      refute String.duplicate("b", 40) in token_texts
      # 41 chars - should be filtered
      refute String.duplicate("c", 41) in token_texts
    end

    test "remove_long_threshold=nil keeps all words regardless of length" do
      # Register tokenizer with remove_long disabled
      Tokenizer.register_text_analyzer(
        "test_long_words_disabled",
        "simple",
        true,
        nil,
        nil,
        nil
      )

      # Test text with words of various lengths (avoiding underscores which tokenize)
      # 39 chars
      # 40 chars
      # 41 chars
      test_text =
        "short medium " <>
          String.duplicate("a", 39) <>
          " " <>
          String.duplicate("b", 40) <>
          " " <>
          String.duplicate("c", 41)

      tokens = Tokenizer.tokenize_text("test_long_words_disabled", test_text)

      # Extract just the text values (tokenize_text returns a list of strings)
      token_texts = tokens

      # All words should be present regardless of length when remove_long_threshold=nil
      assert "short" in token_texts
      assert "medium" in token_texts
      # 39 chars
      assert String.duplicate("a", 39) in token_texts
      # 40 chars
      assert String.duplicate("b", 40) in token_texts
      # 41 chars
      assert String.duplicate("c", 41) in token_texts
    end

    test "threshold can be configured to filter words at custom lengths" do
      # Register tokenizer with remove_long enabled at 40 character threshold
      Tokenizer.register_text_analyzer(
        "test_threshold_verification",
        "simple",
        true,
        nil,
        nil,
        40
      )

      # Test words right at the boundary - actual threshold is 39 chars
      test_cases = [
        # 1 char
        {"a", 1, :kept},
        # 4 chars
        {"word", 4, :kept},
        # 34 chars
        {"supercalifragilisticexpialidocious", 34, :kept},
        # 38 chars (corrected)
        {"pneumonoultramicroscopicsilicovolcanic", 38, :kept},
        # 39 chars (at boundary)
        {String.duplicate("a", 39), 39, :kept},
        # 40 chars (should be filtered)
        {String.duplicate("b", 40), 40, :filtered},
        # 41 chars (should be filtered)
        {String.duplicate("c", 41), 41, :filtered},
        # 45 chars
        {"supercalifragilisticexpialidociousandsomemore", 45, :filtered}
      ]

      for {word, expected_length, expected_result} <- test_cases do
        # Verify our test word lengths are correct
        assert String.length(word) == expected_length,
               "Test word '#{word}' should be #{expected_length} chars but is #{String.length(word)} chars"

        tokens = Tokenizer.tokenize_text("test_threshold_verification", word)
        token_texts = tokens

        case expected_result do
          :kept ->
            assert word in token_texts,
                   "Word '#{word}' (#{expected_length} chars) should be kept but was filtered"

          :filtered ->
            refute word in token_texts,
                   "Word '#{word}' (#{expected_length} chars) should be filtered but was kept"
        end
      end
    end

    test "remove_long_threshold works with other filters" do
      # Test remove_long_threshold combined with stop words and stemming
      Tokenizer.register_text_analyzer(
        "test_combined_filters",
        "simple",
        true,
        "english",
        "english",
        40
      )

      # 53 chars
      test_text =
        "the running " <>
          "supercalifragilisticexpialidociouswordthatisverylong"

      tokens = Tokenizer.tokenize_text("test_combined_filters", test_text)
      token_texts = tokens

      # "the" should be filtered by stop words
      refute "the" in token_texts

      # "running" should be stemmed to "run"
      assert "run" in token_texts

      # Long word should be filtered by remove_long
      refute "supercalifragilisticexpialidociouswordthatisverylong" in token_texts
    end

    test "remove_long filter order is applied after other filters" do
      # This test verifies that the filter is applied in the correct order
      # Based on the Rust code, the order is: lowercase -> stop words -> stemming -> remove_long

      Tokenizer.register_text_analyzer(
        "test_filter_order",
        "simple",
        true,
        "english",
        "english",
        40
      )

      # Use a word that will be affected by stemming but is long
      # 47 chars, ends with "ises"
      long_stemmed_word = "pneumonoultramicroscopicsilicovolcaniconiosises"

      tokens = Tokenizer.tokenize_text("test_filter_order", long_stemmed_word)
      token_texts = tokens

      # The word should be filtered out due to length, regardless of what stemming would do
      refute long_stemmed_word in token_texts

      # There shouldn't be any stemmed version either, since it gets filtered by length first
      assert length(token_texts) == 0
    end
  end

  describe "unified API with configurable threshold" do
    test "accepts nil threshold to disable filtering" do
      # Register tokenizer with no long word filtering
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "no_threshold_filter",
                 "simple",
                 true,
                 nil,
                 nil,
                 nil
               )

      # Test with very long words - they should all be kept
      # 50 chars
      # 100 chars
      # 200 chars
      test_text =
        "short " <>
          String.duplicate("a", 50) <>
          " " <>
          String.duplicate("b", 100) <>
          " " <>
          String.duplicate("c", 200)

      tokens = Tokenizer.tokenize_text("no_threshold_filter", test_text)

      # All words should be present regardless of length when threshold is nil
      assert "short" in tokens
      assert String.duplicate("a", 50) in tokens
      assert String.duplicate("b", 100) in tokens
      assert String.duplicate("c", 200) in tokens
    end

    test "accepts custom threshold values" do
      test_cases = [
        {10, "test_threshold_10"},
        {25, "test_threshold_25"},
        {50, "test_threshold_50"},
        {100, "test_threshold_100"}
      ]

      for {threshold, analyzer_name} <- test_cases do
        # Register tokenizer with custom threshold
        assert {:ok, _} =
                 Tokenizer.register_text_analyzer(
                   analyzer_name,
                   "simple",
                   true,
                   nil,
                   nil,
                   threshold
                 )

        # Test words at the boundary
        word_at_threshold = String.duplicate("a", threshold)
        word_over_threshold = String.duplicate("b", threshold + 1)
        word_under_threshold = String.duplicate("c", threshold - 1)

        # Test each word individually to avoid tokenization complications
        tokens_at = Tokenizer.tokenize_text(analyzer_name, word_at_threshold)
        tokens_over = Tokenizer.tokenize_text(analyzer_name, word_over_threshold)
        tokens_under = Tokenizer.tokenize_text(analyzer_name, word_under_threshold)

        # Word under threshold should be kept
        assert word_under_threshold in tokens_under,
               "Word of #{threshold - 1} chars should be kept with threshold #{threshold}"

        # Word at threshold should be filtered (Tantivy filters words >= threshold)
        refute word_at_threshold in tokens_at,
               "Word of #{threshold} chars should be filtered with threshold #{threshold}"

        # Word over threshold should be filtered
        refute word_over_threshold in tokens_over,
               "Word of #{threshold + 1} chars should be filtered with threshold #{threshold}"
      end
    end

    test "works with other filters (stop words, stemming)" do
      # Register with custom threshold and other filters
      Tokenizer.register_text_analyzer(
        "combined_filters_custom",
        "simple",
        true,
        "english",
        "english",
        # Custom threshold of 20 characters
        20
      )

      # 34 chars - over our 20 char threshold
      test_text =
        "the running " <>
          "supercalifragilisticexpialidocious"

      tokens = Tokenizer.tokenize_text("combined_filters_custom", test_text)

      # "the" should be filtered by stop words
      refute "the" in tokens

      # "running" should be stemmed to "run"
      assert "run" in tokens

      # Long word should be filtered by our custom threshold (34 chars > 20 char threshold)
      refute "supercalifragilisticexpialidocious" in tokens
    end

    test "validates threshold parameter type" do
      # Should accept positive integers
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "valid_threshold_1",
                 "simple",
                 true,
                 nil,
                 nil,
                 1
               )

      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "valid_threshold_100",
                 "simple",
                 true,
                 nil,
                 nil,
                 100
               )

      # Should accept nil
      assert {:ok, _} =
               Tokenizer.register_text_analyzer(
                 "valid_threshold_nil",
                 "simple",
                 true,
                 nil,
                 nil,
                 nil
               )
    end

    test "very strict threshold filters appropriately" do
      # Test with a very low threshold
      Tokenizer.register_text_analyzer(
        "very_strict",
        "simple",
        true,
        nil,
        nil,
        5
      )

      # Test more carefully with individual words
      # 4 chars
      tokens_4 = Tokenizer.tokenize_text("very_strict", "four")
      # 5 chars
      tokens_5 = Tokenizer.tokenize_text("very_strict", "fiver")
      # 6 chars
      tokens_6 = Tokenizer.tokenize_text("very_strict", "sixers")

      # Under threshold (4 < 5) - kept
      assert "four" in tokens_4
      # At threshold (5 >= 5) - filtered
      refute "fiver" in tokens_5
      # Over threshold (6 >= 5) - filtered
      refute "sixers" in tokens_6
    end

    test "very permissive threshold keeps long words" do
      # Test with a very high threshold
      Tokenizer.register_text_analyzer(
        "very_permissive",
        "simple",
        true,
        nil,
        nil,
        1000
      )

      # Create some very long words
      # 340 chars
      very_long_word = String.duplicate("supercalifragilisticexpialidocious", 10)
      extremely_long_word = String.duplicate("a", 500)

      test_text = "short #{very_long_word} #{extremely_long_word}"

      tokens = Tokenizer.tokenize_text("very_permissive", test_text)

      # All words should be kept with such a high threshold
      assert "short" in tokens
      assert very_long_word in tokens
      assert extremely_long_word in tokens
    end

    test "default 40-character threshold behavior" do
      # Test the equivalent of the old hardcoded behavior
      Tokenizer.register_text_analyzer(
        "test_documented_behavior",
        "simple",
        true,
        nil,
        nil,
        40
      )

      # Test the actual threshold behavior
      exactly_39_chars = String.duplicate("a", 39)
      exactly_40_chars = String.duplicate("a", 40)
      exactly_41_chars = String.duplicate("a", 41)

      tokens_39 = Tokenizer.tokenize_text("test_documented_behavior", exactly_39_chars)
      tokens_40 = Tokenizer.tokenize_text("test_documented_behavior", exactly_40_chars)
      tokens_41 = Tokenizer.tokenize_text("test_documented_behavior", exactly_41_chars)

      # 39 chars should be kept (under the threshold)
      assert length(tokens_39) == 1
      assert hd(tokens_39) == exactly_39_chars

      # 40 chars should be filtered (at the threshold)
      assert length(tokens_40) == 0

      # 41 chars should be filtered (over the threshold)
      assert length(tokens_41) == 0
    end

    test "threshold behavior with convenience functions" do
      # Test stemming tokenizer with threshold
      assert {:ok, _} = Tokenizer.register_stemming_tokenizer("english", 30)

      # Test language analyzer with threshold
      assert {:ok, _} = Tokenizer.register_language_analyzer("english", 50)

      # Test that both work correctly
      # 7 chars
      short_word = "running"
      # 29 chars
      medium_word = String.duplicate("a", 29)
      # 35 chars
      long_word = String.duplicate("b", 35)

      # Stemming tokenizer should stem "running" to "run" and filter long words at 30 chars
      # The convenience function creates an analyzer named "english_stem"
      stemming_tokens =
        Tokenizer.tokenize_text("english_stem", "#{short_word} #{medium_word} #{long_word}")

      # stemmed from "running"
      assert "run" in stemming_tokens
      # 29 chars < 30 threshold
      assert medium_word in stemming_tokens
      # 35 chars >= 30 threshold
      refute long_word in stemming_tokens

      # Language analyzer should filter long words at 50 chars
      # The convenience function creates an analyzer named "english_text"
      language_tokens =
        Tokenizer.tokenize_text("english_text", "#{short_word} #{medium_word} #{long_word}")

      # stemmed from "running"
      assert "run" in language_tokens
      # 29 chars < 50 threshold
      assert medium_word in language_tokens
      # 35 chars < 50 threshold
      assert long_word in language_tokens
    end
  end
end
