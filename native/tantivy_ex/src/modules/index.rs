use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tantivy::Index;

use crate::modules::resources::{IndexResource, IndexWriterResource, SchemaResource};

/// Index creation and management functions
#[rustler::nif]
pub fn index_create_in_dir(
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
pub fn index_create_in_ram(
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<ResourceArc<IndexResource>> {
    let index = Index::create_in_ram(schema_res.schema.clone());
    Ok(ResourceArc::new(IndexResource {
        index: Arc::new(index),
    }))
}

#[rustler::nif]
pub fn index_writer(
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

#[rustler::nif]
pub fn index_reader<'a>(env: Env<'a>, index_res: ResourceArc<IndexResource>) -> NifResult<Term<'a>> {
    match index_res.index.reader() {
        Ok(reader) => {
            let searcher = reader.searcher();
            let searcher_res = ResourceArc::new(crate::modules::resources::SearcherResource {
                searcher: Arc::new(searcher),
            });
            Ok(searcher_res.encode(env))
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to create index reader: {}",
            e
        )))),
    }
}
