defmodule TantivyEx.Tokenizer do
  @moduledoc """
  Provides comprehensive tokenization functionality for TantivyEx.

  This module allows you to register and use various types of tokenizers including:
  - Simple and whitespace tokenizers
  - Regex-based tokenizers
  - N-gram tokenizers
  - Text analyzers with filters (lowercase, stop words, stemming)
  - Language-specific stemmers
  - Pre-tokenized text support

  ## Basic Usage

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      "Default tokenizers registered successfully"

      iex> TantivyEx.Tokenizer.tokenize_text("simple", "Hello World!")
      ["hello", "world"]

  ## Advanced Usage

      # Register a custom regex tokenizer
      iex> TantivyEx.Tokenizer.register_regex_tokenizer("email", "\\\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Z|a-z]{2,}\\\\b")
      "Regex tokenizer 'email' registered successfully"

      # Register a text analyzer with multiple filters
      iex> TantivyEx.Tokenizer.register_text_analyzer(
      ...>   "en_full",
      ...>   "simple",
      ...>   true,  # lowercase
      ...>   "en",  # stop words
      ...>   "en",  # stemming
      ...>   40     # remove long tokens threshold
      ...> )
      {:ok, "Text analyzer 'en_full' registered successfully"}

  ## Supported Languages

  The following languages are supported for stop words and stemming:
  - English (en)
  - French (fr)
  - German (de)
  - Spanish (es)
  - Italian (it)
  - Portuguese (pt)
  - Russian (ru)
  - Japanese (ja)
  - Korean (ko)
  - Arabic (ar)
  - Hindi (hi)
  - Chinese (zh)
  - Danish (da)
  - Dutch (nl)
  - Finnish (fi)
  - Hungarian (hu)
  - Norwegian (no)
  - Romanian (ro)
  - Swedish (sv)
  - Tamil (ta)
  - Turkish (tr)
  """

  alias TantivyEx.Native

  @type tokenizer_name :: String.t()
  @type tokenizer_result :: {:ok, String.t()} | {:error, String.t()}
  @type tokens :: [String.t()]
  @type detailed_tokens :: [{String.t(), non_neg_integer(), non_neg_integer()}]

  @doc """
  Register default tokenizers with sensible configurations.

  This registers commonly used tokenizers including:
  - `"default"`, `"simple"`, `"whitespace"`, `"raw"`
  - Language-specific stemmers: `"en_stem"`, `"fr_stem"`, etc.
  - English text analyzer: `"en_text"` (lowercase + stop words + stemming)

  ## Examples

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      "Default tokenizers registered successfully"
  """
  @spec register_default_tokenizers() :: String.t()
  def register_default_tokenizers do
    case Native.register_default_tokenizers() do
      {:ok, result} -> result
      result when is_binary(result) -> result
      {:error, reason} -> raise "Failed to register default tokenizers: #{reason}"
    end
  end

  @doc """
  Register a simple tokenizer.

  Simple tokenizers split text on whitespace and punctuation, converting to lowercase.

  ## Parameters

  - `name`: Name to register the tokenizer under

  ## Examples

      iex> TantivyEx.Tokenizer.register_simple_tokenizer("my_simple")
      "Simple tokenizer 'my_simple' registered successfully"
  """
  @spec register_simple_tokenizer(tokenizer_name()) :: tokenizer_result()
  def register_simple_tokenizer(name) when is_binary(name) do
    case Native.register_simple_tokenizer(name) do
      {:ok, result} -> {:ok, result}
      result when is_binary(result) -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Register a whitespace tokenizer.

  Whitespace tokenizers split text only on whitespace characters.

  ## Parameters

  - `name`: Name to register the tokenizer under

  ## Examples

      iex> TantivyEx.Tokenizer.register_whitespace_tokenizer("whitespace_only")
      "Whitespace tokenizer 'whitespace_only' registered successfully"
  """
  @spec register_whitespace_tokenizer(tokenizer_name()) :: tokenizer_result()
  def register_whitespace_tokenizer(name) when is_binary(name) do
    case Native.register_whitespace_tokenizer(name) do
      {:ok, result} -> {:ok, result}
      result when is_binary(result) -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Register a regex-based tokenizer.

  Regex tokenizers split text based on a regular expression pattern.

  ## Parameters

  - `name`: Name to register the tokenizer under
  - `pattern`: Regular expression pattern for tokenization

  ## Examples

      # Split on any non-alphanumeric character
      iex> TantivyEx.Tokenizer.register_regex_tokenizer("alphanum", "[^a-zA-Z0-9]+")
      "Regex tokenizer 'alphanum' registered successfully"

      # Extract email addresses
      iex> TantivyEx.Tokenizer.register_regex_tokenizer("email", "\\\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Z|a-z]{2,}\\\\b")
      "Regex tokenizer 'email' registered successfully"
  """
  @spec register_regex_tokenizer(tokenizer_name(), String.t()) :: tokenizer_result()
  def register_regex_tokenizer(name, pattern) when is_binary(name) and is_binary(pattern) do
    case Native.register_regex_tokenizer(name, pattern) do
      {:ok, result} -> {:ok, result}
      result when is_binary(result) -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Register an N-gram tokenizer.

  N-gram tokenizers generate character or word n-grams of specified lengths.

  ## Parameters

  - `name`: Name to register the tokenizer under
  - `min_gram`: Minimum n-gram length
  - `max_gram`: Maximum n-gram length
  - `prefix_only`: If true, only generate n-grams from the beginning of tokens

  ## Examples

      # Character bigrams and trigrams
      iex> TantivyEx.Tokenizer.register_ngram_tokenizer("char_2_3", 2, 3, false)
      "N-gram tokenizer 'char_2_3' registered successfully"

      # Prefix-only trigrams
      iex> TantivyEx.Tokenizer.register_ngram_tokenizer("prefix_3", 3, 3, true)
      "N-gram tokenizer 'prefix_3' registered successfully"
  """
  @spec register_ngram_tokenizer(tokenizer_name(), pos_integer(), pos_integer(), boolean()) ::
          tokenizer_result()
  def register_ngram_tokenizer(name, min_gram, max_gram, prefix_only)
      when is_binary(name) and is_integer(min_gram) and is_integer(max_gram) and
             is_boolean(prefix_only) do
    case Native.register_ngram_tokenizer(name, min_gram, max_gram, prefix_only) do
      {:ok, result} -> {:ok, result}
      result when is_binary(result) -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Register a comprehensive text analyzer with multiple filters.

  Text analyzers chain together a base tokenizer with various token filters.

  ## Parameters

  - `name`: Name to register the text analyzer under
  - `base_tokenizer`: Base tokenizer ("simple" or "whitespace")
  - `lowercase`: Whether to apply lowercase filter
  - `stop_words_language`: Language for stop words filter (nil to disable)
  - `stemming_language`: Language for stemming filter (nil to disable)
  - `remove_long_threshold`: Custom threshold for long word removal (nil to disable, integer for custom threshold)

  ## Examples

      # Full English text analyzer with default 40-character threshold
      iex> TantivyEx.Tokenizer.register_text_analyzer(
      ...>   "en_full",
      ...>   "simple",
      ...>   true,
      ...>   "en",
      ...>   "en",
      ...>   40
      ...> )
      {:ok, "Text analyzer 'en_full' registered successfully"}

      # Custom threshold of 50 characters
      iex> TantivyEx.Tokenizer.register_text_analyzer(
      ...>   "custom_threshold",
      ...>   "simple",
      ...>   true,
      ...>   "en",
      ...>   "en",
      ...>   50
      ...> )
      {:ok, "Text analyzer 'custom_threshold' registered successfully"}

      # Disable long word filtering entirely
      iex> TantivyEx.Tokenizer.register_text_analyzer(
      ...>   "no_long_filter",
      ...>   "simple",
      ...>   true,
      ...>   "en",
      ...>   "en",
      ...>   nil
      ...> )
      {:ok, "Text analyzer 'no_long_filter' registered successfully"}

      # French analyzer with stop words only
      iex> TantivyEx.Tokenizer.register_text_analyzer(
      ...>   "fr_stop",
      ...>   "simple",
      ...>   true,
      ...>   "fr",
      ...>   nil,
      ...>   nil
      ...> )
      {:ok, "Text analyzer 'fr_stop' registered successfully"}
  """
  @spec register_text_analyzer(
          tokenizer_name(),
          String.t(),
          boolean(),
          String.t() | nil,
          String.t() | nil,
          pos_integer() | nil
        ) :: tokenizer_result()
  def register_text_analyzer(
        name,
        base_tokenizer,
        lowercase,
        stop_words_language,
        stemming_language,
        remove_long_threshold
      )
      when is_binary(name) and is_binary(base_tokenizer) and is_boolean(lowercase) and
             (is_nil(remove_long_threshold) or is_integer(remove_long_threshold)) do
    case Native.register_text_analyzer(
           name,
           base_tokenizer,
           lowercase,
           stop_words_language,
           stemming_language,
           remove_long_threshold
         ) do
      {:ok, result} -> {:ok, result}
      result when is_binary(result) -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a list of all registered tokenizers.

  ## Examples

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      iex> tokenizers = TantivyEx.Tokenizer.list_tokenizers()
      iex> "default" in tokenizers
      true
      iex> "en_stem" in tokenizers
      true
  """
  @spec list_tokenizers() :: [String.t()]
  def list_tokenizers do
    case Native.list_tokenizers() do
      tokenizers when is_list(tokenizers) -> tokenizers
      {:error, reason} -> raise "Failed to list tokenizers: #{reason}"
    end
  end

  @doc """
  Tokenize text using a registered tokenizer.

  ## Parameters

  - `tokenizer_name`: Name of the registered tokenizer
  - `text`: Text to tokenize

  ## Examples

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      iex> TantivyEx.Tokenizer.tokenize_text("simple", "Hello, World!")
      ["hello", "world"]

      iex> TantivyEx.Tokenizer.tokenize_text("en_stem", "running quickly")
      ["run", "quickli"]
  """
  @spec tokenize_text(tokenizer_name(), String.t()) :: tokens()
  def tokenize_text(tokenizer_name, text) when is_binary(tokenizer_name) and is_binary(text) do
    case Native.tokenize_text(tokenizer_name, text) do
      {:ok, tokens} -> tokens
      tokens when is_list(tokens) -> tokens
      {:error, reason} -> raise "Tokenization failed: #{reason}"
    end
  end

  @doc """
  Tokenize text and return detailed token information including positions.

  Returns tuples of {token, start_offset, end_offset}.

  ## Parameters

  - `tokenizer_name`: Name of the registered tokenizer
  - `text`: Text to tokenize

  ## Examples

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      iex> TantivyEx.Tokenizer.tokenize_text_detailed("simple", "Hello World")
      [{"hello", 0, 5}, {"world", 6, 11}]
  """
  @spec tokenize_text_detailed(tokenizer_name(), String.t()) :: detailed_tokens()
  def tokenize_text_detailed(tokenizer_name, text)
      when is_binary(tokenizer_name) and is_binary(text) do
    case Native.tokenize_text_detailed(tokenizer_name, text) do
      {:ok, tokens} -> tokens
      tokens when is_list(tokens) -> tokens
      {:error, reason} -> raise "Detailed tokenization failed: #{reason}"
    end
  end

  @doc """
  Process pre-tokenized text.

  Useful when you have already tokenized text and want to pass it to Tantivy.

  ## Parameters

  - `tokens`: List of pre-tokenized strings

  ## Examples

      iex> tokens = ["hello", "world", "test"]
      iex> TantivyEx.Tokenizer.process_pre_tokenized_text(tokens)
      "PreTokenizedString([\"hello\", \"world\", \"test\"])"
  """
  @spec process_pre_tokenized_text([String.t()]) :: String.t()
  def process_pre_tokenized_text(tokens) when is_list(tokens) do
    case Native.process_pre_tokenized_text(tokens) do
      {:ok, result} -> result
      result when is_binary(result) -> result
      {:error, reason} -> raise "Failed to process pre-tokenized text: #{reason}"
    end
  end

  @doc """
  Register a language-specific stemming tokenizer.

  This is a convenience function that creates a text analyzer with lowercasing and stemming
  for the specified language.

  ## Parameters

  - `language`: Language code (e.g., "en", "fr", "de")
  - `remove_long_threshold`: Optional threshold for long word removal (nil to disable, integer for custom threshold)

  ## Examples

      iex> TantivyEx.Tokenizer.register_stemming_tokenizer("en")
      "Text analyzer 'en_stem' registered successfully"

      iex> TantivyEx.Tokenizer.register_stemming_tokenizer("fr")
      "Text analyzer 'fr_stem' registered successfully"

      iex> TantivyEx.Tokenizer.register_stemming_tokenizer("en", 50)
      "Text analyzer 'en_stem' registered successfully"
  """
  @spec register_stemming_tokenizer(String.t()) :: tokenizer_result()
  @spec register_stemming_tokenizer(String.t(), pos_integer() | nil) :: tokenizer_result()
  def register_stemming_tokenizer(language, remove_long_threshold \\ nil)
      when is_binary(language) do
    tokenizer_name = "#{language}_stem"
    register_text_analyzer(tokenizer_name, "simple", true, nil, language, remove_long_threshold)
  end

  @doc """
  Register a language-specific text analyzer with stop words and stemming.

  This creates a comprehensive text analyzer for the specified language including
  lowercasing, stop word removal, and stemming.

  ## Parameters

  - `language`: Language code (e.g., "en", "fr", "de")
  - `remove_long_threshold`: Optional threshold for long word removal (nil to disable, integer for custom threshold)

  ## Examples

      iex> TantivyEx.Tokenizer.register_language_analyzer("en")
      "Text analyzer 'en_text' registered successfully"

      iex> TantivyEx.Tokenizer.register_language_analyzer("de")
      "Text analyzer 'de_text' registered successfully"

      iex> TantivyEx.Tokenizer.register_language_analyzer("en", 60)
      "Text analyzer 'en_text' registered successfully"
  """
  @spec register_language_analyzer(String.t()) :: tokenizer_result()
  @spec register_language_analyzer(String.t(), pos_integer() | nil) :: tokenizer_result()
  def register_language_analyzer(language, remove_long_threshold \\ nil)
      when is_binary(language) do
    tokenizer_name = "#{language}_text"

    register_text_analyzer(
      tokenizer_name,
      "simple",
      true,
      language,
      language,
      remove_long_threshold
    )
  end

  @doc """
  Test tokenization performance with a given tokenizer and text.

  Returns timing information along with the tokens.

  ## Parameters

  - `tokenizer_name`: Name of the registered tokenizer
  - `text`: Text to tokenize
  - `iterations`: Number of iterations to run (default: 1000)

  ## Examples

      iex> TantivyEx.Tokenizer.register_default_tokenizers()
      iex> {tokens, microseconds} = TantivyEx.Tokenizer.benchmark_tokenizer("simple", "Hello World", 100)
      iex> is_list(tokens) and is_number(microseconds)
      true
  """
  @spec benchmark_tokenizer(tokenizer_name(), String.t(), pos_integer()) :: {tokens(), number()}
  def benchmark_tokenizer(tokenizer_name, text, iterations \\ 1000) do
    start_time = System.monotonic_time(:microsecond)

    tokens =
      Enum.reduce(1..iterations, [], fn _, _acc ->
        tokenize_text(tokenizer_name, text)
      end)

    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time

    {tokens, duration / iterations}
  end
end
