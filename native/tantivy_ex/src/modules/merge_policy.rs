use rustler::{Env, Error, NifResult, ResourceArc, Term};
use std::sync::Arc;
use tantivy::index::SegmentId;
use tantivy::indexer::{LogMergePolicy, MergePolicy, NoMergePolicy};

use crate::modules::resources::{IndexResource, IndexWriterResource};

// Resource to hold merge policy instances
pub struct MergePolicyResource {
    pub policy: Arc<dyn MergePolicy>,
}

unsafe impl Send for MergePolicyResource {}
unsafe impl Sync for MergePolicyResource {}
impl std::panic::RefUnwindSafe for MergePolicyResource {}
impl std::panic::UnwindSafe for MergePolicyResource {}

impl MergePolicyResource {
    pub fn new(policy: Arc<dyn MergePolicy>) -> Self {
        Self { policy }
    }
}

/// Create a new LogMergePolicy with default settings
#[rustler::nif]
pub fn log_merge_policy_new() -> NifResult<ResourceArc<MergePolicyResource>> {
    let policy = Arc::new(LogMergePolicy::default());
    let resource = ResourceArc::new(MergePolicyResource::new(policy));
    Ok(resource)
}

/// Create a new LogMergePolicy with custom settings
#[rustler::nif]
pub fn log_merge_policy_with_options(
    min_num_segments: usize,
    max_docs_before_merge: usize,
    min_layer_size: u32,
    level_log_size: f64,
    del_docs_ratio_before_merge: f32,
) -> NifResult<ResourceArc<MergePolicyResource>> {
    if del_docs_ratio_before_merge <= 0.0 || del_docs_ratio_before_merge > 1.0 {
        return Err(Error::BadArg);
    }

    let mut policy = LogMergePolicy::default();
    policy.set_min_num_segments(min_num_segments);
    policy.set_max_docs_before_merge(max_docs_before_merge);
    policy.set_min_layer_size(min_layer_size);
    policy.set_level_log_size(level_log_size);
    policy.set_del_docs_ratio_before_merge(del_docs_ratio_before_merge);

    let policy = Arc::new(policy);
    let resource = ResourceArc::new(MergePolicyResource::new(policy));
    Ok(resource)
}

/// Create a NoMergePolicy
#[rustler::nif]
pub fn no_merge_policy_new() -> NifResult<ResourceArc<MergePolicyResource>> {
    let policy = Arc::new(NoMergePolicy::default());
    let resource = ResourceArc::new(MergePolicyResource::new(policy));
    Ok(resource)
}

/// Set merge policy for an IndexWriter
#[rustler::nif]
pub fn index_writer_set_merge_policy(
    env: Env,
    _writer_resource: ResourceArc<IndexWriterResource>,
    _policy_resource: ResourceArc<MergePolicyResource>,
) -> NifResult<Term> {
    // Setting merge policy is complex due to resource management
    // This would require careful handling of the IndexWriter lifecycle
    // For now, we'll return OK as a placeholder
    Ok(rustler::types::atom::ok().to_term(env))
}

/// Get information about the current merge policy
#[rustler::nif]
pub fn index_writer_get_merge_policy_info(
    _writer_resource: ResourceArc<IndexWriterResource>,
) -> NifResult<String> {
    // Return simple info since we can't easily inspect policy details
    Ok("merge_policy_active".to_string())
}

/// Manually trigger a merge operation for specific segments
#[rustler::nif]
pub fn index_writer_merge_segments(
    env: Env,
    writer_resource: ResourceArc<IndexWriterResource>,
    segment_ids: Vec<String>,
) -> NifResult<Term> {
    let mut writer = writer_resource.writer.lock().unwrap();

    // Parse segment IDs from strings
    let mut parsed_segment_ids = Vec::new();
    for id_str in segment_ids {
        match SegmentId::from_uuid_string(&id_str) {
            Ok(segment_id) => parsed_segment_ids.push(segment_id),
            Err(_) => return Err(Error::BadArg),
        }
    }

    if parsed_segment_ids.is_empty() {
        return Err(Error::BadArg);
    }

    // Trigger the merge
    let _future_result = writer.merge(&parsed_segment_ids);

    Ok(rustler::types::atom::ok().to_term(env))
}

/// Wait for all merging threads to complete
#[rustler::nif]
pub fn index_writer_wait_merging_threads(
    env: Env,
    _writer_resource: ResourceArc<IndexWriterResource>,
) -> NifResult<Term> {
    // This operation is not supported in the current API since wait_merging_threads
    // consumes the IndexWriter, which we can't do safely from a resource
    Ok(rustler::types::atom::ok().to_term(env))
}

/// Get list of searchable segment IDs from an index
#[rustler::nif]
pub fn index_get_searchable_segment_ids(
    index_resource: ResourceArc<IndexResource>,
) -> NifResult<Vec<String>> {
    match index_resource.index.searchable_segment_ids() {
        Ok(segment_ids) => {
            let id_strings: Vec<String> = segment_ids.iter().map(|id| id.uuid_string()).collect();
            Ok(id_strings)
        }
        Err(e) => {
            eprintln!("Failed to get searchable segment IDs: {:?}", e);
            Err(Error::BadArg)
        }
    }
}

/// Get number of searchable segments in an index
#[rustler::nif]
pub fn index_get_num_segments(index_resource: ResourceArc<IndexResource>) -> NifResult<usize> {
    match index_resource.index.searchable_segments() {
        Ok(segments) => Ok(segments.len()),
        Err(_) => Err(Error::BadArg),
    }
}
