defmodule TantivyEx.Native do
  @moduledoc false

  use Rustler,
    otp_app: :tantivy_ex,
    crate: "tantivy_ex",
    skip_compilation?: false

  # Schema functions
  def schema_builder_new(), do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_text_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_text_field_with_tokenizer(_schema, _field_name, _options, _tokenizer),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_u64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_i64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_f64_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_bool_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_date_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_facet_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_bytes_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_json_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_add_ip_addr_field(_schema, _field_name, _options),
    do: :erlang.nif_error(:nif_not_loaded)

  # Schema introspection functions
  def schema_get_field_names(_schema),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_get_field_type(_schema, _field_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def schema_validate(_schema),
    do: :erlang.nif_error(:nif_not_loaded)

  # Index functions
  def index_create_in_dir(_path, _schema), do: :erlang.nif_error(:nif_not_loaded)
  def index_create_in_ram(_schema), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer(_index, _memory_budget), do: :erlang.nif_error(:nif_not_loaded)

  # Writer functions
  def writer_add_document(_writer, _document_json), do: :erlang.nif_error(:nif_not_loaded)
  def writer_commit(_writer), do: :erlang.nif_error(:nif_not_loaded)

  # Enhanced document operations
  def writer_add_document_with_schema(_writer, _document, _schema),
    do: :erlang.nif_error(:nif_not_loaded)

  def writer_add_document_batch(_writer, _documents, _schema),
    do: :erlang.nif_error(:nif_not_loaded)

  def validate_document_against_schema(_document, _schema), do: :erlang.nif_error(:nif_not_loaded)

  # Search functions
  def index_reader(_index), do: :erlang.nif_error(:nif_not_loaded)

  def searcher_search(_searcher, _query, _limit, _include_docs),
    do: :erlang.nif_error(:nif_not_loaded)

  # Query Parser functions
  def query_parser_new(_schema, _default_fields), do: :erlang.nif_error(:nif_not_loaded)
  def query_parser_parse(_parser, _query_str), do: :erlang.nif_error(:nif_not_loaded)

  # Query building functions
  def query_term(_schema, _field_name, _term_value), do: :erlang.nif_error(:nif_not_loaded)
  def query_phrase(_schema, _field_name, _phrase_terms), do: :erlang.nif_error(:nif_not_loaded)
  def query_range_u64(_schema, _field_name, _start, _end), do: :erlang.nif_error(:nif_not_loaded)
  def query_range_i64(_schema, _field_name, _start, _end), do: :erlang.nif_error(:nif_not_loaded)
  def query_range_f64(_schema, _field_name, _start, _end), do: :erlang.nif_error(:nif_not_loaded)

  def query_boolean(_must_queries, _should_queries, _must_not_queries),
    do: :erlang.nif_error(:nif_not_loaded)

  def query_fuzzy(_schema, _field_name, _term_value, _distance, _prefix),
    do: :erlang.nif_error(:nif_not_loaded)

  def query_wildcard(_schema, _field_name, _pattern), do: :erlang.nif_error(:nif_not_loaded)
  def query_regex(_schema, _field_name, _pattern), do: :erlang.nif_error(:nif_not_loaded)

  def query_phrase_prefix(_schema, _field_name, _phrase_terms, _max_expansions),
    do: :erlang.nif_error(:nif_not_loaded)

  def query_exists(_schema, _field_name), do: :erlang.nif_error(:nif_not_loaded)
  def query_all(), do: :erlang.nif_error(:nif_not_loaded)
  def query_empty(), do: :erlang.nif_error(:nif_not_loaded)

  def query_more_like_this(
        _schema,
        _document,
        _min_doc_frequency,
        _max_doc_frequency,
        _min_term_frequency,
        _max_query_terms,
        _min_word_length,
        _max_word_length,
        _boost_factor
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def query_extract_terms(_query, _schema), do: :erlang.nif_error(:nif_not_loaded)

  # Enhanced search function
  def searcher_search_with_query(_searcher, _query, _limit, _include_docs),
    do: :erlang.nif_error(:nif_not_loaded)

  # Tokenizer functions
  def tokenizer_manager_new(), do: :erlang.nif_error(:nif_not_loaded)
  def register_simple_tokenizer(_name), do: :erlang.nif_error(:nif_not_loaded)
  def register_whitespace_tokenizer(_name), do: :erlang.nif_error(:nif_not_loaded)
  def register_regex_tokenizer(_name, _pattern), do: :erlang.nif_error(:nif_not_loaded)

  def register_ngram_tokenizer(_name, _min_gram, _max_gram, _prefix_only),
    do: :erlang.nif_error(:nif_not_loaded)

  def register_text_analyzer(
        _name,
        _base_tokenizer,
        _lowercase,
        _stop_words_language,
        _stemming_language,
        _remove_long_threshold
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def list_tokenizers(), do: :erlang.nif_error(:nif_not_loaded)
  def tokenize_text(_tokenizer_name, _text), do: :erlang.nif_error(:nif_not_loaded)
  def tokenize_text_detailed(_tokenizer_name, _text), do: :erlang.nif_error(:nif_not_loaded)
  def process_pre_tokenized_text(_tokens), do: :erlang.nif_error(:nif_not_loaded)
  def register_default_tokenizers(), do: :erlang.nif_error(:nif_not_loaded)

  # Aggregation functions
  def run_aggregations(_searcher, _query, _aggregations_json),
    do: :erlang.nif_error(:nif_not_loaded)

  def run_search_with_aggregations(_searcher, _query, _aggregations_json, _search_limit),
    do: :erlang.nif_error(:nif_not_loaded)
end
