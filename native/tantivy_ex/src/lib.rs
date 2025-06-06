use base64;
use base64::{engine::general_purpose, Engine as _};
use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use serde_json;
use std::collections::HashMap;
use std::panic::{RefUnwindSafe, UnwindSafe};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tantivy::collector::TopDocs;
use tantivy::query::Occur;
use tantivy::query::{
    AllQuery, BooleanQuery, EmptyQuery, ExistsQuery, FuzzyTermQuery, MoreLikeThisQuery,
    PhrasePrefixQuery, PhraseQuery, QueryParser, RangeQuery, RegexQuery, TermQuery,
};
use tantivy::schema::{
    BytesOptions, DateOptions, FacetOptions, Field, FieldType, IpAddrOptions, JsonObjectOptions,
    NumericOptions, OwnedValue, Schema, TextFieldIndexing, TextOptions, Value,
};
use tantivy::{Index, IndexWriter, TantivyDocument, Term as TantivyTerm};

// Resource types for managing state
pub struct IndexResource {
    pub index: Arc<Index>,
}

// Make IndexResource safe for unwind
unsafe impl Send for IndexResource {}
unsafe impl Sync for IndexResource {}
impl RefUnwindSafe for IndexResource {}
impl UnwindSafe for IndexResource {}

pub struct SchemaResource {
    pub schema: Schema,
}

pub struct IndexWriterResource {
    pub writer: Arc<Mutex<IndexWriter>>,
}

pub struct SearcherResource {
    pub searcher: Arc<tantivy::Searcher>,
}

pub struct QueryResource {
    pub query: Box<dyn tantivy::query::Query>,
}

pub struct QueryParserResource {
    pub parser: QueryParser,
}

// Make SearcherResource safe for unwind
unsafe impl Send for SearcherResource {}
unsafe impl Sync for SearcherResource {}
impl RefUnwindSafe for SearcherResource {}
impl UnwindSafe for SearcherResource {}

unsafe impl Send for QueryResource {}
unsafe impl Sync for QueryResource {}
impl RefUnwindSafe for QueryResource {}
impl UnwindSafe for QueryResource {}

unsafe impl Send for QueryParserResource {}
unsafe impl Sync for QueryParserResource {}
impl RefUnwindSafe for QueryParserResource {}
impl UnwindSafe for QueryParserResource {}

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
    }
}

// Resource type declaration
rustler::init! {
    "Elixir.TantivyEx.Native",
    load = load
}

// Initialize resources
fn load(env: rustler::Env, _: rustler::Term) -> bool {
    let _ = rustler::resource!(SchemaResource, env);
    let _ = rustler::resource!(IndexResource, env);
    let _ = rustler::resource!(IndexWriterResource, env);
    let _ = rustler::resource!(SearcherResource, env);
    let _ = rustler::resource!(QueryResource, env);
    let _ = rustler::resource!(QueryParserResource, env);
    true
}

// Schema building functions
#[rustler::nif]
fn schema_builder_new() -> rustler::ResourceArc<SchemaResource> {
    let schema = Schema::builder().build();
    rustler::ResourceArc::new(SchemaResource { schema })
}

#[rustler::nif]
fn schema_add_text_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options for the new field
    let field_options = match options.as_str() {
        "TEXT_STORED" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default())
            .set_stored(),
        "TEXT" => TextOptions::default().set_indexing_options(TextFieldIndexing::default()),
        "STORED" => TextOptions::default().set_stored(),
        "FAST" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default())
            .set_fast(None),
        "FAST_STORED" => TextOptions::default()
            .set_indexing_options(
                TextFieldIndexing::default()
                    .set_index_option(tantivy::schema::IndexRecordOption::WithFreqsAndPositions),
            )
            .set_stored()
            .set_fast(None),
        _ => TextOptions::default().set_indexing_options(TextFieldIndexing::default()),
    };

    schema_builder.add_text_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_text_field_with_tokenizer(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
    tokenizer: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options and configure with custom tokenizer
    let field_options = match options.as_str() {
        "TEXT_STORED" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer))
            .set_stored(),
        "TEXT" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer)),
        "STORED" => {
            // For STORED-only fields, we don't set indexing options or tokenizer
            TextOptions::default().set_stored()
        }
        _ => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer)),
    };

    schema_builder.add_text_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_u64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options for the new field
    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_u64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_i64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_i64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_f64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_f64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_bool_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_bool_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_date_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => DateOptions::default().set_indexed().set_stored(),
        "INDEXED" => DateOptions::default().set_indexed(),
        "STORED" => DateOptions::default().set_stored(),
        "FAST" => DateOptions::default().set_fast(),
        "FAST_STORED" => DateOptions::default().set_fast().set_stored(),
        _ => DateOptions::default().set_indexed(),
    };

    schema_builder.add_date_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_facet_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    _options: String, // Facet fields don't use the same options pattern
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Facet fields are always indexed and stored by default
    let field_options = FacetOptions::default();

    schema_builder.add_facet_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_bytes_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => BytesOptions::default().set_indexed().set_stored(),
        "INDEXED" => BytesOptions::default().set_indexed(),
        "STORED" => BytesOptions::default().set_stored(),
        "FAST" => BytesOptions::default().set_fast(),
        "FAST_STORED" => BytesOptions::default().set_fast().set_stored(),
        _ => BytesOptions::default().set_stored(), // Bytes are typically stored
    };

    schema_builder.add_bytes_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_json_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "STORED" => JsonObjectOptions::default().set_stored(),
        _ => JsonObjectOptions::default(), // JSON fields are indexed by default
    };

    schema_builder.add_json_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
fn schema_add_ip_addr_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => IpAddrOptions::default().set_indexed().set_stored(),
        "INDEXED" => IpAddrOptions::default().set_indexed(),
        "STORED" => IpAddrOptions::default().set_stored(),
        "FAST" => IpAddrOptions::default().set_fast(),
        "FAST_STORED" => IpAddrOptions::default().set_fast().set_stored(),
        _ => IpAddrOptions::default().set_indexed(),
    };

    schema_builder.add_ip_addr_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

// Helper function to copy existing fields (DRY principle)
fn copy_existing_fields_to_builder(
    schema: &Schema,
    schema_builder: &mut tantivy::schema::SchemaBuilder,
) {
    for (field, field_entry) in schema.fields() {
        let field_name_existing = schema.get_field_name(field);
        match field_entry.field_type() {
            FieldType::Str(text_options) => {
                schema_builder.add_text_field(field_name_existing, text_options.clone());
            }
            FieldType::U64(int_options) => {
                schema_builder.add_u64_field(field_name_existing, int_options.clone());
            }
            FieldType::I64(int_options) => {
                schema_builder.add_i64_field(field_name_existing, int_options.clone());
            }
            FieldType::F64(float_options) => {
                schema_builder.add_f64_field(field_name_existing, float_options.clone());
            }
            FieldType::Bool(bool_options) => {
                schema_builder.add_bool_field(field_name_existing, bool_options.clone());
            }
            FieldType::Date(date_options) => {
                schema_builder.add_date_field(field_name_existing, date_options.clone());
            }
            FieldType::Facet(facet_options) => {
                schema_builder.add_facet_field(field_name_existing, facet_options.clone());
            }
            FieldType::Bytes(bytes_options) => {
                schema_builder.add_bytes_field(field_name_existing, bytes_options.clone());
            }
            FieldType::JsonObject(json_options) => {
                schema_builder.add_json_field(field_name_existing, json_options.clone());
            }
            FieldType::IpAddr(ip_options) => {
                schema_builder.add_ip_addr_field(field_name_existing, ip_options.clone());
            }
        }
    }
}

// Index creation and management
#[rustler::nif]
fn index_create_in_dir(
    path: String,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<ResourceArc<IndexResource>> {
    let index_path = Path::new(&path);

    // Create the directory if it doesn't exist
    if !index_path.exists() {
        if let Err(e) = std::fs::create_dir_all(index_path) {
            return Err(rustler::Error::Term(Box::new(format!(
                "Failed to create directory: {}",
                e
            ))));
        }
    }

    match Index::create_in_dir(index_path, schema_res.schema.clone()) {
        Ok(index) => Ok(ResourceArc::new(IndexResource {
            index: Arc::new(index),
        })),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to create index: {}",
            e
        )))),
    }
}

#[rustler::nif]
fn index_create_in_ram(
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<ResourceArc<IndexResource>> {
    let index = Index::create_in_ram(schema_res.schema.clone());
    Ok(ResourceArc::new(IndexResource {
        index: Arc::new(index),
    }))
}

#[rustler::nif]
fn index_writer(
    index_res: ResourceArc<IndexResource>,
    memory_budget: u64,
) -> NifResult<ResourceArc<IndexWriterResource>> {
    match index_res.index.writer(memory_budget as usize) {
        Ok(writer) => Ok(ResourceArc::new(IndexWriterResource {
            writer: Arc::new(Mutex::new(writer)),
        })),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to create writer: {}",
            e
        )))),
    }
}

// Document operations
#[rustler::nif]
fn writer_add_document<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    document: rustler::Term<'a>,
) -> NifResult<Term<'a>> {
    // Convert Elixir map to a HashMap first
    let doc_map: HashMap<String, rustler::Term> = match document.decode() {
        Ok(map) => map,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(
                "Failed to decode document map: Expected a map".to_string(),
            )))
        }
    };

    // Convert the HashMap to a serde_json::Value
    let mut doc_object = serde_json::Map::new();
    for (key, value) in doc_map {
        if let Ok(string_val) = value.decode::<String>() {
            doc_object.insert(key, serde_json::Value::String(string_val));
        } else if let Ok(int_val) = value.decode::<i64>() {
            doc_object.insert(
                key,
                serde_json::Value::Number(serde_json::Number::from(int_val)),
            );
        } else if let Ok(float_val) = value.decode::<f64>() {
            if let Some(num) = serde_json::Number::from_f64(float_val) {
                doc_object.insert(key, serde_json::Value::Number(num));
            }
        } else if let Ok(bool_val) = value.decode::<bool>() {
            doc_object.insert(key, serde_json::Value::Bool(bool_val));
        }
        // Add more types as needed
    }

    let doc_data = serde_json::Value::Object(doc_object);

    let writer = writer_res.writer.lock().unwrap();

    // Create a document from the JSON data
    let mut tantivy_doc = TantivyDocument::default();

    if let serde_json::Value::Object(obj) = doc_data {
        for (_key, value) in obj {
            match value {
                serde_json::Value::String(s) => {
                    // For now, add all strings as text to the first text field (field 0)
                    // In a production implementation, you'd need to map fields properly
                    tantivy_doc.add_text(Field::from_field_id(0), &s);
                }
                serde_json::Value::Number(n) => {
                    if let Some(i) = n.as_u64() {
                        // Add numbers to the first numeric field
                        // This is a simplified approach - proper field mapping needed
                        tantivy_doc.add_u64(Field::from_field_id(1), i);
                    }
                }
                _ => {
                    // Handle other types as needed - for now ignore
                }
            }
        }
    }

    match writer.add_document(tantivy_doc) {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to add document: {}",
            e
        )))),
    }
}

#[rustler::nif]
fn writer_commit<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
) -> NifResult<Term<'a>> {
    let mut writer = writer_res.writer.lock().unwrap();
    match writer.commit() {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to commit: {}",
            e
        )))),
    }
}

// Search operations
#[rustler::nif]
fn index_reader(index_res: ResourceArc<IndexResource>) -> NifResult<ResourceArc<SearcherResource>> {
    match index_res.index.reader() {
        Ok(reader) => {
            let searcher = reader.searcher();
            Ok(ResourceArc::new(SearcherResource {
                searcher: Arc::new(searcher),
            }))
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to create reader: {}",
            e
        )))),
    }
}

#[rustler::nif]
fn searcher_search(
    searcher_res: ResourceArc<SearcherResource>,
    _query_str: String,
    limit: u64,
) -> NifResult<String> {
    // This is a simplified search implementation
    // In a real implementation, you'd need to parse the query properly
    // and handle different query types

    let all_query = AllQuery;
    match searcher_res
        .searcher
        .search(&all_query, &TopDocs::with_limit(limit as usize))
    {
        Ok(top_docs) => {
            let mut results = Vec::new();
            for (_score, doc_address) in top_docs {
                if let Ok(_doc) = searcher_res.searcher.doc::<TantivyDocument>(doc_address) {
                    // Convert document to JSON - simplified
                    results.push(format!("{{\"doc_id\": {}}}", doc_address.doc_id));
                }
            }
            Ok(format!("[{}]", results.join(",")))
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Search failed: {}",
            e
        )))),
    }
}

// COMPREHENSIVE QUERY SYSTEM

// Query Parser Functions
#[rustler::nif]
fn query_parser_new(
    index_res: ResourceArc<IndexResource>,
    default_fields: Vec<String>,
) -> NifResult<ResourceArc<QueryParserResource>> {
    // Need at least one default field
    if default_fields.is_empty() {
        return Err(rustler::Error::Term(Box::new(
            "At least one default field is required for query parser",
        )));
    }

    // Convert field names to Field objects
    let mut fields = Vec::new();
    for field_name in default_fields {
        if let Ok(field) = index_res.index.schema().get_field(&field_name) {
            fields.push(field);
        } else {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found in schema",
                field_name
            ))));
        }
    }

    // If we couldn't find any of the fields, return error
    if fields.is_empty() {
        return Err(rustler::Error::Term(Box::new(
            "None of the specified fields were found in schema",
        )));
    }

    // Create the parser using fields we found
    let parser = QueryParser::for_index(&*index_res.index, fields);
    Ok(ResourceArc::new(QueryParserResource { parser }))
}

#[rustler::nif]
fn query_parser_parse(
    parser_res: ResourceArc<QueryParserResource>,
    query_str: String,
) -> NifResult<ResourceArc<QueryResource>> {
    // Check if query string is empty
    if query_str.trim().is_empty() {
        return Err(rustler::Error::Term(Box::new(
            "Query string cannot be empty",
        )));
    }

    match parser_res.parser.parse_query(&query_str) {
        Ok(query) => Ok(ResourceArc::new(QueryResource { query })),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to parse query: {}",
            e
        )))),
    }
}

// Term Query
#[rustler::nif]
fn query_term(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    term_value: String,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let term = TantivyTerm::from_field_text(field, &term_value);
    let query = TermQuery::new(term, tantivy::schema::IndexRecordOption::Basic);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Phrase Query
#[rustler::nif]
fn query_phrase(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    phrase_terms: Vec<String>,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let terms: Vec<TantivyTerm> = phrase_terms
        .into_iter()
        .map(|term_str| TantivyTerm::from_field_text(field, &term_str))
        .collect();

    let query = PhraseQuery::new(terms);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Range Query for numeric fields
#[rustler::nif]
fn query_range_u64(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    start: Option<u64>,
    end: Option<u64>,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let start_term = match start {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_u64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let end_term = match end {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_u64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let query = RangeQuery::new(start_term, end_term);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Range Query for i64 fields
#[rustler::nif]
fn query_range_i64(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    start: Option<i64>,
    end: Option<i64>,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let start_term = match start {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_i64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let end_term = match end {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_i64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let query = RangeQuery::new(start_term, end_term);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Range Query for f64 fields
#[rustler::nif]
fn query_range_f64(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    start: Option<f64>,
    end: Option<f64>,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let start_term = match start {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_f64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let end_term = match end {
        Some(val) => std::ops::Bound::Included(TantivyTerm::from_field_f64(field, val)),
        None => std::ops::Bound::Unbounded,
    };

    let query = RangeQuery::new(start_term, end_term);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Boolean Query
#[rustler::nif]
fn query_boolean(
    must_queries: Vec<ResourceArc<QueryResource>>,
    should_queries: Vec<ResourceArc<QueryResource>>,
    must_not_queries: Vec<ResourceArc<QueryResource>>,
) -> NifResult<ResourceArc<QueryResource>> {
    let mut clauses = Vec::new();

    // Add MUST clauses (AND)
    for query_res in must_queries {
        clauses.push((Occur::Must, query_res.query.box_clone()));
    }

    // Add SHOULD clauses (OR)
    for query_res in should_queries {
        clauses.push((Occur::Should, query_res.query.box_clone()));
    }

    // Add MUST NOT clauses (NOT)
    for query_res in must_not_queries {
        clauses.push((Occur::MustNot, query_res.query.box_clone()));
    }

    let boolean_query = BooleanQuery::new(clauses);

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(boolean_query),
    }))
}

// Fuzzy Query
#[rustler::nif]
fn query_fuzzy(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    term_value: String,
    distance: u8,
    prefix: bool,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let term = TantivyTerm::from_field_text(field, &term_value);
    let query = FuzzyTermQuery::new(term, distance, prefix);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Regex Query
#[rustler::nif]
fn query_regex(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    pattern: String,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    match RegexQuery::from_pattern(&pattern, field) {
        Ok(query) => Ok(ResourceArc::new(QueryResource {
            query: Box::new(query),
        })),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to create regex query: {}",
            e
        )))),
    }
}

// Wildcard Query - implemented as a simple wrapper around RegexQuery
// with a modified pattern to avoid empty match operators
#[rustler::nif]
fn query_wildcard(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    pattern: String,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    // Simple wildcard pattern to regex conversion
    let mut regex_pattern = String::new();
    for c in pattern.chars() {
        match c {
            '*' => regex_pattern.push_str(".*"),
            '?' => regex_pattern.push('.'),
            c if ['[', ']', '(', ')', '{', '}', '.', '+', '^', '$', '|'].contains(&c) => {
                regex_pattern.push('\\');
                regex_pattern.push(c);
            }
            _ => regex_pattern.push(c),
        }
    }

    // Create a RegexQuery directly with the converted pattern
    match RegexQuery::from_pattern(&regex_pattern, field) {
        Ok(query) => Ok(ResourceArc::new(QueryResource {
            query: Box::new(query),
        })),
        Err(e) => {
            // Fall back to simple term query if regex fails
            if pattern.ends_with('*')
                && !pattern[..pattern.len() - 1].contains('*')
                && !pattern.contains('?')
            {
                // Simple prefix query for patterns like "abc*"
                let prefix = &pattern[..pattern.len() - 1];
                let term_query = TermQuery::new(
                    TantivyTerm::from_field_text(field, prefix),
                    tantivy::schema::IndexRecordOption::WithFreqs,
                );
                Ok(ResourceArc::new(QueryResource {
                    query: Box::new(term_query),
                }))
            } else {
                Err(rustler::Error::Term(Box::new(format!(
                    "Failed to create wildcard query: {}",
                    e
                ))))
            }
        }
    }
}

// Phrase Prefix Query
#[rustler::nif]
fn query_phrase_prefix(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    phrase_terms: Vec<String>,
    max_expansions: u32,
) -> NifResult<ResourceArc<QueryResource>> {
    let field = match schema_res.schema.get_field(&field_name) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found",
                field_name
            ))))
        }
    };

    let terms: Vec<TantivyTerm> = phrase_terms
        .into_iter()
        .map(|term_str| TantivyTerm::from_field_text(field, &term_str))
        .collect();

    let mut query = PhrasePrefixQuery::new(terms);
    query.set_max_expansions(max_expansions);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Exists Query
#[rustler::nif]
fn query_exists(
    _schema_res: ResourceArc<SchemaResource>,
    field_name: String,
) -> NifResult<ResourceArc<QueryResource>> {
    // In tantivy 0.24.1, ExistsQuery::new takes field name and json_subpaths boolean
    let query = ExistsQuery::new(field_name, false);
    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// All Query (matches all documents)
#[rustler::nif]
fn query_all() -> ResourceArc<QueryResource> {
    let query = AllQuery;
    ResourceArc::new(QueryResource {
        query: Box::new(query),
    })
}

// Empty Query (matches no documents)
#[rustler::nif]
fn query_empty() -> ResourceArc<QueryResource> {
    let query = EmptyQuery;
    ResourceArc::new(QueryResource {
        query: Box::new(query),
    })
}

// More Like This Query with proper tantivy 0.24.1 implementation
#[rustler::nif]
fn query_more_like_this(
    schema_res: ResourceArc<SchemaResource>,
    doc_json: String,
    min_doc_frequency: Option<u64>,
    max_doc_frequency: Option<u64>,
    min_term_frequency: Option<usize>,
    max_query_terms: Option<usize>,
    min_word_length: Option<usize>,
    max_word_length: Option<usize>,
    boost_factor: Option<f32>,
) -> NifResult<ResourceArc<QueryResource>> {
    // Parse the document JSON to extract field values
    let doc_data: serde_json::Value = match serde_json::from_str(&doc_json) {
        Ok(data) => data,
        Err(e) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "JSON parse error: {}",
                e
            ))))
        }
    };

    // Extract field values from the JSON document
    let mut doc_fields = Vec::new();
    if let serde_json::Value::Object(obj) = doc_data {
        for (field_name, value) in obj {
            // Get the Field from schema
            if let Ok(field) = schema_res.schema.get_field(&field_name) {
                let mut field_values = Vec::new();

                // Convert JSON value to tantivy OwnedValue
                match value {
                    serde_json::Value::String(s) => {
                        field_values.push(tantivy::schema::OwnedValue::Str(s));
                    }
                    serde_json::Value::Number(n) => {
                        if let Some(i) = n.as_u64() {
                            field_values.push(tantivy::schema::OwnedValue::U64(i));
                        } else if let Some(i) = n.as_i64() {
                            field_values.push(tantivy::schema::OwnedValue::I64(i));
                        } else if let Some(f) = n.as_f64() {
                            field_values.push(tantivy::schema::OwnedValue::F64(f));
                        }
                    }
                    serde_json::Value::Bool(b) => {
                        field_values.push(tantivy::schema::OwnedValue::Bool(b));
                    }
                    serde_json::Value::Array(arr) => {
                        // Handle arrays by adding each element
                        for item in arr {
                            match item {
                                serde_json::Value::String(s) => {
                                    field_values.push(tantivy::schema::OwnedValue::Str(s));
                                }
                                _ => {} // Skip non-string array elements for now
                            }
                        }
                    }
                    _ => {} // Skip other types for now
                }

                if !field_values.is_empty() {
                    doc_fields.push((field, field_values));
                }
            }
        }
    }

    if doc_fields.is_empty() {
        return Err(rustler::Error::Term(Box::new(
            "No valid field values found in document for MoreLikeThisQuery".to_string(),
        )));
    }

    // Build the MoreLikeThisQuery using the new 0.24.1 API
    let mut builder = MoreLikeThisQuery::builder();

    // Set optional parameters
    if let Some(min_doc_freq) = min_doc_frequency {
        builder = builder.with_min_doc_frequency(min_doc_freq);
    }

    if let Some(max_doc_freq) = max_doc_frequency {
        builder = builder.with_max_doc_frequency(max_doc_freq);
    }

    if let Some(min_term_freq) = min_term_frequency {
        builder = builder.with_min_term_frequency(min_term_freq);
    }

    if let Some(max_query_terms) = max_query_terms {
        builder = builder.with_max_query_terms(max_query_terms);
    }

    if let Some(min_word_len) = min_word_length {
        builder = builder.with_min_word_length(min_word_len);
    }

    if let Some(max_word_len) = max_word_length {
        builder = builder.with_max_word_length(max_word_len);
    }

    if let Some(boost) = boost_factor {
        builder = builder.with_boost_factor(boost);
    }

    // Create the query with document fields
    let query = builder.with_document_fields(doc_fields);

    Ok(ResourceArc::new(QueryResource {
        query: Box::new(query),
    }))
}

// Enhanced Search with Query Resource
#[rustler::nif]
fn searcher_search_with_query(
    searcher_res: ResourceArc<SearcherResource>,
    query_res: ResourceArc<QueryResource>,
    limit: u64,
    include_docs: bool,
) -> NifResult<String> {
    match searcher_res
        .searcher
        .search(&*query_res.query, &TopDocs::with_limit(limit as usize))
    {
        Ok(top_docs) => {
            let mut results = Vec::new();
            for (score, doc_address) in top_docs {
                if include_docs {
                    if let Ok(doc) = searcher_res.searcher.doc::<TantivyDocument>(doc_address) {
                        // Convert document to JSON representation
                        let mut doc_map = serde_json::Map::new();
                        doc_map.insert(
                            "score".to_string(),
                            serde_json::Value::Number(
                                serde_json::Number::from_f64(score as f64)
                                    .unwrap_or(serde_json::Number::from(0)),
                            ),
                        );
                        doc_map.insert(
                            "doc_id".to_string(),
                            serde_json::Value::Number(serde_json::Number::from(
                                doc_address.doc_id as u64,
                            )),
                        );

                        // Add document fields
                        for (field, value) in doc.field_values() {
                            let field_name = searcher_res.searcher.schema().get_field_name(field);
                            let json_value = if let Some(s) = value.as_str() {
                                serde_json::Value::String(s.to_string())
                            } else if let Some(n) = value.as_u64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_i64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_f64() {
                                serde_json::Value::Number(
                                    serde_json::Number::from_f64(n)
                                        .unwrap_or(serde_json::Number::from(0)),
                                )
                            } else if let Some(b) = value.as_bool() {
                                serde_json::Value::Bool(b)
                            } else if let Some(d) = value.as_datetime() {
                                serde_json::Value::String(format!("{:?}", d))
                            } else if let Some(f) = value.as_facet() {
                                serde_json::Value::String(f.to_string())
                            } else if let Some(b) = value.as_bytes() {
                                serde_json::Value::String(general_purpose::STANDARD.encode(b))
                            } else if let Some(obj_iter) = value.as_object() {
                                // Convert object iterator to JSON value
                                let mut json_obj = serde_json::Map::new();
                                for (key, val) in obj_iter {
                                    // For now, just convert to string - could be enhanced later
                                    json_obj.insert(
                                        key.to_string(),
                                        serde_json::Value::String(format!("{:?}", val)),
                                    );
                                }
                                serde_json::Value::Object(json_obj)
                            } else if let Some(ip) = value.as_ip_addr() {
                                serde_json::Value::String(ip.to_string())
                            } else {
                                serde_json::Value::Null
                            };
                            doc_map.insert(field_name.to_string(), json_value);
                        }

                        results.push(serde_json::Value::Object(doc_map));
                    }
                } else {
                    // Just return score and doc_id
                    let mut doc_map = serde_json::Map::new();
                    doc_map.insert(
                        "score".to_string(),
                        serde_json::Value::Number(
                            serde_json::Number::from_f64(score as f64)
                                .unwrap_or(serde_json::Number::from(0)),
                        ),
                    );
                    doc_map.insert(
                        "doc_id".to_string(),
                        serde_json::Value::Number(serde_json::Number::from(
                            doc_address.doc_id as u64,
                        )),
                    );
                    results.push(serde_json::Value::Object(doc_map));
                }
            }

            match serde_json::to_string(&results) {
                Ok(json) => Ok(json),
                Err(e) => Err(rustler::Error::Term(Box::new(format!(
                    "Failed to serialize results: {}",
                    e
                )))),
            }
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Search failed: {}",
            e
        )))),
    }
}

// Schema introspection functions
#[rustler::nif]
fn schema_get_field_names(schema_res: ResourceArc<SchemaResource>) -> Vec<String> {
    schema_res
        .schema
        .fields()
        .map(|(_, field_entry)| field_entry.name().to_string())
        .collect()
}

#[rustler::nif]
fn schema_get_field_type(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
) -> NifResult<String> {
    // Find the field by name
    for (_field, field_entry) in schema_res.schema.fields() {
        if field_entry.name() == field_name {
            let field_type_name = match field_entry.field_type() {
                FieldType::Str(_) => "text",
                FieldType::U64(_) => "u64",
                FieldType::I64(_) => "i64",
                FieldType::F64(_) => "f64",
                FieldType::Bool(_) => "bool",
                FieldType::Date(_) => "date",
                FieldType::Facet(_) => "facet",
                FieldType::Bytes(_) => "bytes",
                FieldType::JsonObject(_) => "json",
                FieldType::IpAddr(_) => "ip_addr",
            };
            return Ok(field_type_name.to_string());
        }
    }

    Err(rustler::Error::Term(Box::new(format!(
        "Field '{}' not found in schema",
        field_name
    ))))
}

#[rustler::nif]
fn schema_validate(schema_res: ResourceArc<SchemaResource>) -> NifResult<String> {
    // Basic schema validation - check if schema has at least one field
    let field_count = schema_res.schema.fields().count();

    if field_count == 0 {
        Err(rustler::Error::Term(Box::new(
            "Schema must have at least one field".to_string(),
        )))
    } else {
        Ok(format!("Schema is valid with {} fields", field_count))
    }
}
