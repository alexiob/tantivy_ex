use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use serde_json;
use std::panic::{RefUnwindSafe, UnwindSafe};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tantivy::collector::TopDocs;
use tantivy::query::AllQuery;
use tantivy::schema::{
    BytesOptions, DateOptions, FacetOptions, Field, FieldType, IpAddrOptions, JsonObjectOptions,
    NumericOptions, Schema, TextFieldIndexing, TextOptions,
};
use tantivy::{Index, IndexWriter, TantivyDocument};

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

// Make SearcherResource safe for unwind
unsafe impl Send for SearcherResource {}
unsafe impl Sync for SearcherResource {}
impl RefUnwindSafe for SearcherResource {}
impl UnwindSafe for SearcherResource {}

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
    document_json: String,
) -> NifResult<Term<'a>> {
    let doc_data: serde_json::Value = match serde_json::from_str(&document_json) {
        Ok(data) => data,
        Err(e) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "JSON parse error: {}",
                e
            ))))
        }
    };

    let mut writer = writer_res.writer.lock().unwrap();

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
