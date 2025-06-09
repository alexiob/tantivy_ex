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

  # Facet functions
  def facet_collector_for_field(_field_name), do: :erlang.nif_error(:nif_not_loaded)
  def facet_collector_add_facet(_collector, _facet_path), do: :erlang.nif_error(:nif_not_loaded)
  def facet_search(_searcher, _query, _collector), do: :erlang.nif_error(:nif_not_loaded)
  def facet_term_query(_field_name, _facet_path), do: :erlang.nif_error(:nif_not_loaded)
  def facet_multi_query(_field_name, _facet_paths, _occur), do: :erlang.nif_error(:nif_not_loaded)
  def facet_from_text(_facet_path), do: :erlang.nif_error(:nif_not_loaded)
  def facet_to_string(_facet), do: :erlang.nif_error(:nif_not_loaded)

  # Merge Policy functions
  def log_merge_policy_new(), do: :erlang.nif_error(:nif_not_loaded)

  def log_merge_policy_with_options(
        _min_num_segments,
        _max_docs_before_merge,
        _min_layer_size,
        _level_log_size,
        _del_docs_ratio_before_merge
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def no_merge_policy_new(), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer_set_merge_policy(_writer, _policy), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer_get_merge_policy_info(_writer), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer_merge_segments(_writer, _segment_ids), do: :erlang.nif_error(:nif_not_loaded)
  def index_writer_wait_merging_threads(_writer), do: :erlang.nif_error(:nif_not_loaded)
  def index_get_searchable_segment_ids(_index), do: :erlang.nif_error(:nif_not_loaded)
  def index_get_num_segments(_index), do: :erlang.nif_error(:nif_not_loaded)

  # Aggregation functions
  def run_aggregations(_searcher, _query, _aggregations_json),
    do: :erlang.nif_error(:nif_not_loaded)

  def run_search_with_aggregations(_searcher, _query, _aggregations_json, _search_limit),
    do: :erlang.nif_error(:nif_not_loaded)

  # Index Warming functions
  def index_warming_new(), do: :erlang.nif_error(:nif_not_loaded)

  def index_warming_configure(
        _warming,
        _cache_size_mb,
        _ttl_seconds,
        _strategy,
        _eviction_policy,
        _background_warming
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def index_warming_add_preload_queries(_warming, _queries),
    do: :erlang.nif_error(:nif_not_loaded)

  def index_warming_warm_index(_warming, _index, _cache_key),
    do: :erlang.nif_error(:nif_not_loaded)

  def index_warming_get_searcher(_warming, _cache_key), do: :erlang.nif_error(:nif_not_loaded)
  def index_warming_evict_cache(_warming, _force_all), do: :erlang.nif_error(:nif_not_loaded)
  def index_warming_get_stats(_warming), do: :erlang.nif_error(:nif_not_loaded)
  def index_warming_clear_cache(_warming), do: :erlang.nif_error(:nif_not_loaded)

  # Space Analysis functions
  def space_analysis_new(), do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_configure(
        _analysis,
        _include_file_details,
        _include_field_breakdown,
        _cache_results,
        _cache_ttl_seconds
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_analyze_index(_analysis, _index, _analysis_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_get_cached(_analysis, _analysis_id), do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_compare(_analysis, _analysis_id_1, _analysis_id_2),
    do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_get_recommendations(_analysis, _analysis_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def space_analysis_clear_cache(_analysis), do: :erlang.nif_error(:nif_not_loaded)

  # Custom Collector functions
  def custom_collector_new(), do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_create_scoring_function(_collector, _name, _scoring_type, _parameters),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_create_top_k(_collector, _collector_name, _k, _scoring_function_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_create_aggregation(_collector, _collector_name, _aggregation_specs),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_create_filtering(_collector, _collector_name, _filter_specs),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_execute(_collector, _index_resource, _collector_name, _query_str),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_get_results(_collector, _collector_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_set_field_boosts(_collector, _scoring_function_name, _field_boosts),
    do: :erlang.nif_error(:nif_not_loaded)

  def custom_collector_list_collectors(_collector), do: :erlang.nif_error(:nif_not_loaded)
  def custom_collector_clear_all(_collector), do: :erlang.nif_error(:nif_not_loaded)

  # Reader Manager functions
  def reader_manager_new(), do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_configure_monitoring(
        _manager,
        _track_usage_stats,
        _track_performance,
        _log_reload_events,
        _alert_on_slow_reloads,
        _slow_reload_threshold_ms
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_create_policy(
        _manager,
        _policy_name,
        _policy_type,
        _max_age_seconds,
        _check_interval_seconds,
        _auto_reload,
        _background_reload,
        _preload_segments
      ),
      do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_create_reader(_manager, _index_resource, _reader_id, _policy_name),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_set_policy(_manager, _policy_type, _config),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_add_index(_manager, _index, _index_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_remove_index(_manager, _index_id), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_get_reader(_manager, _index_id), do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_reload_reader(_manager, _reader_id, _force_reload),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_reload_all(_manager), do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_get_reader_stats(_manager, _reader_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_get_reader_health(_manager, _reader_id),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_get_health(_manager), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_get_stats(_manager), do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_record_search(_manager, _reader_id, _search_duration_ms),
    do: :erlang.nif_error(:nif_not_loaded)

  def reader_manager_list_readers(_manager), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_list_policies(_manager), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_shutdown(_manager), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_dispose_reader(_manager, _reader_id), do: :erlang.nif_error(:nif_not_loaded)
  def reader_manager_clear_all(_manager), do: :erlang.nif_error(:nif_not_loaded)
end
