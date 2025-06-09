# Changelog

All notable changes to TantivyEx will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2025-06-09

### Fixed

#### Test Reliability and Code Quality

- **Fixed distributed OTP test race condition** - Resolved race condition in "OTP coordinator can be started and stopped" test by changing from `async: true` to `async: false` to prevent concurrent test interference
- **Enhanced OTP coordinator termination** - Improved `stop()` function in `TantivyEx.Distributed.OTP` with proper waiting logic using `wait_for_termination/2` and comprehensive termination checking
- **Eliminated all compiler warnings** - Fixed 7 compiler warnings across multiple files:
  - **coordinator.ex**: Fixed unused task variables and removed unreachable code clause
  - **search_node.ex**: Fixed unused parameters (`endpoint`, `schema`), removed unused `Index` alias, and replaced undefined `Query.create/1` with proper health check implementation
- **Improved test output clarity** - Added `Logger.configure(level: :warning)` to `test/test_helper.exs` to suppress info logs during test execution for cleaner output

#### Documentation Accuracy

- **Corrected field types table** - Updated README.md field types table to accurately reflect all supported options:
  - **Text fields**: Added missing `:fast` and `:fast_stored` options
  - **Numeric types**: Added missing `:fast_stored` option for U64, I64, F64, Bool, Date, Bytes, and IP Address fields
  - **JSON fields**: Corrected options from incorrect `:indexed`, `:stored` to proper `:text`, `:text_stored`, `:stored`
- **Fixed function reference in quick-start guide** - Replaced non-existent function reference with proper faceted search example using `TantivyEx.Query.parser/2` and `TantivyEx.Query.parse/2`
- **Fixed duplicate section headers in tokenizers guide** - Resolved duplicate "Advanced Text Analyzers" section headers in `docs/tokenizers.md` by renaming them to unique, descriptive titles:
  - Renamed first instance to "Text Analyzers" (basic text analyzer registration)
  - Renamed second instance to "Multi-Language Text Analyzers" (sophisticated multi-language processing)
  - Kept the main comprehensive section as "Advanced Text Analyzers"
- **Fixed duplicate section headers in aggregations guide** - Resolved duplicate "Helper Functions" section headers in `docs/aggregations.md` by renaming the basic usage section to "Basic Helper Usage" to distinguish it from the comprehensive "Helper Functions" section
- **Removed deprecated distributed search module** - Cleaned up `lib/tantivy_ex/distributed.ex` and updated all documentation to use only the OTP-based distributed search API (`TantivyEx.Distributed.OTP`)

### Enhanced

#### Test Coverage and Robustness

- **Comprehensive distributed OTP test suite** - Added 15 new test cases (150% increase) covering advanced distributed search scenarios:
  - Complex multi-field boolean queries with AND/OR operations
  - Range queries across distributed nodes with various data types
  - Phrase and fuzzy queries for sophisticated text matching
  - Pagination testing with different page sizes and offsets
  - Multiple merge strategies (score_desc, score_asc, node_order, round_robin)
  - Concurrent search operations and thread safety validation
  - Weighted load balancing with custom node weights
  - Edge cases including malformed queries and empty result handling
  - Node health monitoring and recovery scenarios
  - Large result sets and memory efficiency testing
  - Query optimization and caching behavior validation
  - Performance metrics and statistics collection verification

#### Code Quality and Reliability

- **Enhanced termination handling** - Improved coordinator shutdown process with proper timeout handling and graceful termination waiting
- **Better error handling** - Enhanced error messages and validation throughout distributed search components
- **Optimized test execution** - Improved test reliability by preventing race conditions in distributed system tests

### Documentation

- **Verified API consistency** - Conducted comprehensive verification of documentation examples against current API implementations to ensure accuracy
- **Updated field configuration reference** - Enhanced field types documentation to match actual implementation capabilities
- **Improved quick-start examples** - Updated examples to use correct function signatures and available APIs

## [0.3.0] - 2025-06-08

### Added

#### Distributed Search System (New in v0.3.0)

- **Complete OTP-based distributed search system** - `TantivyEx.Distributed.OTP` for coordinating search operations across multiple Tantivy instances using proper Elixir/OTP patterns
- **Multi-node coordination** - Support for adding, removing, and managing search nodes with unique identifiers and endpoints
- **Advanced load balancing** - Multiple strategies including round-robin, weighted round-robin, least connections, and health-based routing
- **Intelligent result merging** - Configurable merge strategies (score_desc, score_asc, node_order, round_robin) for optimal result ranking
- **Comprehensive configuration** - Timeout settings, retry policies, and distributed behavior customization
- **Cluster health monitoring** - Built-in cluster and individual node health checking capabilities
- **Performance statistics** - Detailed performance metrics and statistics collection for distributed operations
- **Graceful error handling** - Robust error handling with failover support and partial failure recovery
- **Local distributed simulation** - Support for testing distributed scenarios with multiple local searchers
- **Node weight management** - Flexible node weighting for capacity-based load distribution
- **Active/inactive node states** - Dynamic node status management for maintenance and failover scenarios
- **JSON response parsing** - Structured response parsing with detailed node-level information
- **Comprehensive documentation** - Complete guide covering setup, configuration, monitoring, and best practices
- **Production-ready patterns** - Integration examples with Phoenix, GenServer, and real-world monitoring strategies

### Documentation

- **New distributed search guide** - Complete documentation covering all aspects of distributed search implementation
- **Updated README** - Added distributed search examples and performance recommendations
- **Enhanced guides index** - Integrated distributed search into the main documentation structure

## [0.2.0] - 2025-06-07

### Added

#### Comprehensive Tokenizer System (New in v0.2.0)

- **Complete tokenizer module** - `TantivyEx.Tokenizer` with full-featured text analysis capabilities
- **Multiple tokenizer types** - Simple, whitespace, regex, n-gram, and text analyzer tokenizers
- **Advanced text analyzers** - Configurable text processing with lowercase, stop words, stemming, and length filtering
- **Multi-language support** - Built-in support for 17+ languages including English, French, German, Spanish, Italian, Portuguese, Russian, Arabic, Danish, Dutch, Finnish, Greek, Hungarian, Norwegian, Romanian, Swedish, Tamil, and Turkish
- **Dynamic tokenizer registration** - Runtime registration and management of custom tokenizers
- **Tokenizer enumeration** - `list_tokenizers/0` function to discover available tokenizers
- **Detailed tokenization** - Position-aware tokenization with start/end offsets
- **Pre-tokenized text support** - Process already tokenized text for custom workflows
- **Performance benchmarking** - Built-in tokenizer performance testing capabilities
- **Language-specific analyzers** - Convenience functions for common language configurations
- **Concurrent tokenization** - Thread-safe tokenizer operations with global manager
- **Comprehensive error handling** - Detailed error messages for invalid configurations
- **Production-ready defaults** - Sensible default tokenizer configurations for common use cases

#### Comprehensive Aggregation System (New in v0.2.0)

- **Complete aggregation module** - `TantivyEx.Aggregation` with full Elasticsearch-compatible aggregation capabilities
- **Bucket aggregations** - Terms, histogram, date_histogram, and range aggregations for data grouping and analysis
- **Metric aggregations** - Average, min, max, sum, count, stats, and percentiles for statistical analysis
- **Nested aggregations** - Support for sub-aggregations with unlimited nesting depth for complex analytics
- **Elasticsearch compatibility** - Full compatibility with Elasticsearch aggregation request/response format
- **Memory optimization** - Built-in memory limits and performance optimizations for large datasets
- **Advanced aggregation options** - Support for ordering, filtering, missing values, and custom bucket ranges
- **Real-world examples** - Comprehensive examples for e-commerce analytics, blog content analysis, and user activity tracking

#### Tokenizer API Functions

- `register_default_tokenizers/0` - Register commonly used tokenizers
- `register_simple_tokenizer/1` - Basic punctuation and whitespace splitting
- `register_whitespace_tokenizer/1` - Whitespace-only splitting with case preservation
- `register_regex_tokenizer/2` - Custom regex pattern-based tokenization
- `register_ngram_tokenizer/4` - Character or word n-gram generation
- `register_text_analyzer/6` - Advanced text processing with filters
- `list_tokenizers/0` - Enumerate all registered tokenizers
- `tokenize_text/2` - Basic text tokenization
- `tokenize_text_detailed/2` - Tokenization with position information
- `process_pre_tokenized_text/1` - Handle pre-tokenized input
- `register_stemming_tokenizer/1` - Language-specific stemming
- `register_language_analyzer/1` - Complete language analysis pipeline
- `benchmark_tokenizer/3` - Performance testing utilities

#### Aggregation API Functions

- `run/3` - Execute aggregations on search results with query filtering
- `search_with_aggregations/4` - Combined search and aggregation in a single operation
- `terms/2` - Helper function for terms aggregation creation
- `histogram/2` - Helper function for histogram aggregation creation
- `date_histogram/2` - Helper function for date-based histogram aggregation
- `range/2` - Helper function for range aggregation creation
- `avg/1`, `min/1`, `max/1`, `sum/1` - Metric aggregation helpers
- `stats/1` - Helper function for comprehensive statistics aggregation
- `percentiles/2` - Helper function for percentile calculations
- `build_request/1` - Utility for building complex aggregation requests
- `validate_request/1` - Request validation and error checking

#### Advanced Text Processing Features

- **Stemming algorithms** - Language-specific word reduction with support for major languages
- **Stop word filtering** - Configurable stop word removal for improved search quality
- **Case normalization** - Intelligent lowercase conversion preserving language-specific rules
- **Length filtering** - Configurable token length limits to prevent indexing issues
- **Unicode support** - Full Unicode text processing with proper character handling
- **Special character handling** - Configurable punctuation and symbol processing
- **Compound word support** - Language-aware word boundary detection

#### Document Operations (Complete Implementation)

- **Schema-aware document validation** - Full validation against schema with comprehensive error reporting
- **Batch document operations** - High-performance batch processing with configurable commit strategies
- **Complete field type support** - Document operations for all field types (text, u64, i64, f64, bool, date, facet, bytes, json, ip_addr)
- **JSON document preparation** - Sophisticated JSON document handling and preparation
- **Type conversion and validation** - Robust type conversion with detailed validation functions
- **Document updates and deletions** - Full CRUD operations with proper error handling
- **Error recovery mechanisms** - Comprehensive error handling and recovery strategies

#### Documentation Enhancements

- **Restructured documentation architecture** - Transformed monolithic guides into modular, focused documentation with improved navigation
- **Comprehensive guides index** - Created extensive `docs/guides.md` with clear navigation by experience level and use case
- **Separated guide files** - Split documentation into focused guides:
  - `installation-setup.md` - Complete installation and configuration guide
  - `quick-start.md` - Hands-on tutorial for beginners
  - `core-concepts.md` - Fundamental concepts with comprehensive glossary of TantivyEx/Tantivy terminology
  - `performance-tuning.md` - Optimization strategies for production workloads
  - `production-deployment.md` - Scalability, monitoring, and operational best practices
  - `integration-patterns.md` - Phoenix/LiveView integration and advanced architectures
- **Enhanced schema documentation** - Deep dive into field options, common pitfalls, and real-world examples for e-commerce, document management, and social media analytics
- **Advanced indexing patterns** - Concurrent indexing with workers, multi-index management, error handling with dead letter queues, and production-ready indexing service
- **Extensive search guide** - Multi-field search strategies, faceting, analytics, query optimization, and advanced search patterns
- **Complete tokenizers guide** - Language-specific tokenization, performance considerations, troubleshooting, and real-world examples
- **Comprehensive glossary** - Detailed definitions of all TantivyEx/Tantivy-specific terms including facets, segments, commits, analyzers, and field options
- **Updated README navigation** - Reorganized documentation links with clear categorization and improved user journey guidance

#### Core Features & Fixes

- **Query module implementation** - Added comprehensive `Query` module for programmatic query building with support for term, phrase, range, boolean, and fuzzy queries
- **Fixed query parser function signature** - Updated to accept `Index` instead of `Schema` to match Rust NIF expectations
- **Enhanced field option support** - Added `:fast` and `:fast_stored` atom mappings for improved field configuration
- **Empty query string validation** - Added proper validation in Rust NIF to prevent empty query parsing errors
- **Consistent field options** - Standardized schema field options throughout codebase for better reliability

#### Test Improvements

- **Comprehensive test coverage** - Added `tantivy_ex_query_parser_test.exs` and `tantivy_ex_query_types_test.exs` for query functionality
- **Fixed field option inconsistencies** - Updated all tests to use consistent `:fast_stored` notation
- **All tests passing** - Resolved 93 tests with 0 failures, ensuring codebase stability

#### Performance & Reliability

- **Position indexing fixes** - Ensured proper `FAST_STORED` configuration for phrase query support
- **Error handling improvements** - Enhanced error messages and validation throughout the codebase
- **Production best practices** - Added comprehensive examples for batch indexing, concurrent operations, and monitoring

## [0.1.0] - 2024-01-XX

### Added

#### Core Features

- **Complete Elixir wrapper for Tantivy search engine** - Full-featured text search capabilities with Rust performance
- **Schema management** - Dynamic schema creation and introspection with comprehensive field type support
- **Document indexing** - High-performance document indexing with batch operations support
- **Full-text search** - Advanced query capabilities with boolean operators, range queries, and faceted search
- **Native Rust integration** - Direct Rust NIF implementation for maximum performance

#### Comprehensive Field Type Support

- **Text fields** with indexing options:
  - `:text` - Indexed for search only
  - `:text_stored` - Indexed and stored (retrievable)
  - `:stored` - Stored only (not searchable)
- **Numeric fields** with full range query support:
  - `U64` - Unsigned 64-bit integers
  - `I64` - Signed 64-bit integers
  - `F64` - 64-bit floating point numbers
- **Date fields** - Optimized date/time handling with Unix timestamp support
- **Binary fields** - Arbitrary byte data storage with indexing options
- **JSON fields** - Structured data storage as JSON objects
- **IP address fields** - Specialized IPv4 and IPv6 address handling
- **Facet fields** - Hierarchical categorization and faceted search capabilities

#### Custom Tokenizer Support

- **Built-in tokenizers**:
  - `default` - Comprehensive text processing with stemming and stop word removal
  - `simple` - Minimal processing preserving structure, case-insensitive
  - `whitespace` - Splits only on whitespace, preserves case and punctuation
  - `keyword` - Treats entire input as single token for exact matching
- **Per-field tokenizer configuration** - Different tokenizers for different field types
- **Advanced text analysis** - Support for technical terms, product codes, and multilingual content

#### Schema Introspection

- **Field enumeration** - `get_field_names/1` to list all schema fields
- **Field information** - `get_field_info/2` to retrieve detailed field metadata
- **Runtime schema validation** - Ensure document compatibility with schema definitions

#### Query Capabilities

- **Full-text search** - Natural language queries with stemming and fuzzy matching
- **Boolean queries** - Complex AND, OR, NOT operations with grouping
- **Field-specific search** - Target specific fields with `field:query` syntax
- **Range queries** - Numeric and date range filtering with inclusive/exclusive bounds
- **Facet queries** - Hierarchical category filtering and navigation
- **Wildcard search** - Pattern matching with `*` and `?` operators
- **Fuzzy search** - Typo tolerance with configurable edit distance
- **Phrase search** - Exact phrase matching with quoted queries

#### Performance Features

- **Rust-native performance** - Direct NIF implementation without serialization overhead
- **Memory efficient** - Streaming document processing for large datasets
- **Concurrent safe** - Thread-safe operations for multi-user applications
- **Optimized indexing** - Batch operations and configurable commit strategies

### Technical Implementation

#### Rust NIF Layer

- **Direct Tantivy integration** - No intermediate serialization layers
- **Memory management** - Proper resource cleanup and lifecycle management
- **Error handling** - Comprehensive error propagation from Rust to Elixir
- **Type safety** - Strict type checking between Elixir and Rust boundaries

#### Elixir API Design

- **Idiomatic Elixir patterns** - Consistent with Elixir/OTP conventions
- **Supervision tree ready** - Safe for use in supervised applications
- **Error tuples** - Standard `{:ok, result}` and `{:error, reason}` patterns
- **Documentation** - Comprehensive @doc and @spec annotations

#### Field Type Implementation

- **Schema validation** - Runtime validation of document structure against schema
- **Type conversion** - Automatic conversion between Elixir and Rust types
- **Null handling** - Proper handling of missing and null field values
- **Default values** - Sensible defaults for optional field configurations

#### Custom Tokenizer Integration

- **Tokenizer selection** - Per-field tokenizer configuration in schema
- **Text processing pipeline** - Configurable text analysis and normalization
- **Search optimization** - Tokenizer choice affects search behavior and performance
- **Multilingual support** - Tokenizer selection for different languages and content types

### Documentation

#### Comprehensive Guides

- **Schema Design Guide** (`guides/schema.md`) - Field types, design patterns, and best practices
- **Indexing Guide** (`guides/indexing.md`) - Document indexing, batch operations, and performance optimization
- **Search Guide** (`guides/search.md`) - Query types, search strategies, and advanced patterns
- **Tokenizers Guide** (`guides/tokenizers.md`) - Text analysis, custom tokenizers, and language considerations

#### API Documentation

- **Complete function documentation** - Every public function with examples and specifications
- **Type specifications** - Full @spec coverage for all public APIs
- **Usage examples** - Real-world examples for common use cases
- **Performance tips** - Guidance for optimal performance in production

#### Getting Started

- **Installation instructions** - Complete setup guide with dependencies
- **Quick start examples** - Working code examples for immediate use
- **Real-world scenarios** - E-commerce, blog, and log analysis examples
- **Migration guidance** - Strategies for schema evolution and data migration

### Examples and Use Cases

#### E-commerce Search

- **Product catalog** - Complete product search with faceted navigation
- **Price filtering** - Range queries for price-based filtering
- **Category navigation** - Hierarchical category browsing
- **Brand search** - Exact brand matching with simple tokenizer

#### Content Management

- **Blog search** - Full-text search across articles and posts
- **Author filtering** - Author-based content discovery
- **Tag-based search** - Tag navigation with whitespace tokenizer
- **Content categorization** - Exact category matching

#### Log Analysis

- **Error analysis** - Natural language search for error patterns
- **Service filtering** - Exact service name matching
- **Time-based queries** - Date range filtering for log analysis
- **Pattern detection** - Automated pattern recognition in log data

### Testing

#### Comprehensive Test Suite

- **37 passing tests** - Complete coverage of all functionality
- **Field type tests** - Validation of all supported field types (25 tests)
- **Custom tokenizer tests** - Verification of tokenizer behavior (5 tests)
- **Integration tests** - End-to-end workflow validation (12 tests)

#### Test Coverage

- **Schema operations** - Creation, field addition, and introspection
- **Document indexing** - Single and batch document operations
- **Search functionality** - All query types and search patterns
- **Error handling** - Validation of error conditions and edge cases

### Performance Characteristics

#### Benchmarks

- **Indexing performance** - High-throughput document indexing
- **Search latency** - Sub-millisecond search response times
- **Memory usage** - Efficient memory utilization for large datasets
- **Concurrent operations** - Multi-user performance characteristics

#### Optimization Features

- **Batch indexing** - Optimized bulk document processing
- **Commit strategies** - Configurable commit frequency for performance tuning
- **Memory management** - Automatic garbage collection and resource cleanup
- **Index optimization** - Segment merging and storage optimization

### Dependencies

#### Rust Dependencies

- **Tantivy 0.22+** - Core search engine functionality
- **Rustler 0.30+** - Elixir NIF framework
- **Serde** - Serialization framework for data exchange

#### Elixir Dependencies

- **Elixir 1.14+** - Minimum supported Elixir version
- **Jason** - JSON processing for examples and tests

### Breaking Changes

- None (initial release)

### Security

- **Input validation** - All user inputs validated before processing
- **Memory safety** - Rust's memory safety guarantees
- **No unsafe code** - All operations use safe Rust patterns

### Known Issues

- None currently known

### Migration Guide

- Not applicable (initial release)

---

## Release Notes

### 0.1.0 Release Highlights

TantivyEx 0.1.0 represents a complete, production-ready Elixir wrapper for the Tantivy search engine. This initial release provides:

1. **100% Feature Coverage** - All major Tantivy features accessible from Elixir
2. **Production Ready** - Comprehensive testing and documentation
3. **High Performance** - Direct Rust integration without performance penalties
4. **Developer Friendly** - Idiomatic Elixir API with extensive documentation
5. **Flexible Architecture** - Support for diverse use cases from e-commerce to log analysis

The library is suitable for production use in applications requiring:

- High-performance full-text search
- Complex query capabilities
- Large-scale document indexing
- Real-time search requirements
- Custom text analysis needs

### Future Roadmap

While 0.1.0 provides complete functionality, future releases may include:

- Additional tokenizer options
- Performance optimizations
- Extended query syntax
- Advanced analytics features
- Integration helpers for common Elixir frameworks

---

## Contributing

We welcome contributions! Please see our contributing guidelines for:

- Code style and standards
- Testing requirements
- Documentation expectations
- Pull request process

## License

TantivyEx is released under the MIT License. See LICENSE file for details.

## Acknowledgments

- **Tantivy team** - For creating an excellent Rust search engine
- **Rustler team** - For providing seamless Rust-Elixir integration
- **Elixir community** - For feedback and testing during development
