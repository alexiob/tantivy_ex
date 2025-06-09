use rustler::{Error, NifResult, ResourceArc, Atom};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use std::thread;
use tantivy::Searcher;
use serde_json;

use crate::modules::resources::{IndexResource, SearcherResource};

/// Resource for managing index warming and caching strategies
pub struct IndexWarmingResource {
    pub cache: Arc<Mutex<HashMap<String, CachedSearcher>>>,
    pub config: Arc<Mutex<WarmingConfig>>,
    pub stats: Arc<Mutex<WarmingStats>>,
}

/// Cached searcher with metadata
#[derive(Debug, Clone)]
pub struct CachedSearcher {
    pub searcher: Arc<Searcher>,
    pub created_at: Instant,
    pub access_count: u64,
    pub last_accessed: Instant,
    pub size_bytes: usize,
}

/// Configuration for index warming and caching
#[derive(Debug, Clone)]
pub struct WarmingConfig {
    pub cache_size_limit: usize,
    pub ttl_seconds: u64,
    pub preload_queries: Vec<String>,
    pub warming_strategy: WarmingStrategy,
    pub eviction_policy: EvictionPolicy,
    pub background_warming: bool,
}

/// Strategy for warming up indexes
#[derive(Debug, Clone)]
pub enum WarmingStrategy {
    Eager,      // Warm immediately on index open
    Lazy,       // Warm on first access
    Scheduled,  // Warm at scheduled intervals
    Predictive, // Warm based on usage patterns
}

/// Cache eviction policies
#[derive(Debug, Clone)]
pub enum EvictionPolicy {
    LRU,        // Least Recently Used
    LFU,        // Least Frequently Used
    TTL,        // Time To Live
    Size,       // Size-based eviction
}

/// Statistics for warming and caching
#[derive(Debug, Clone)]
pub struct WarmingStats {
    pub cache_hits: u64,
    pub cache_misses: u64,
    pub evictions: u64,
    pub warming_operations: u64,
    pub total_warming_time_ms: u64,
    pub memory_usage_bytes: usize,
}

// Safety traits for cross-thread usage
unsafe impl Send for IndexWarmingResource {}
unsafe impl Sync for IndexWarmingResource {}
impl std::panic::RefUnwindSafe for IndexWarmingResource {}
impl std::panic::UnwindSafe for IndexWarmingResource {}

impl IndexWarmingResource {
    pub fn new() -> Self {
        Self {
            cache: Arc::new(Mutex::new(HashMap::new())),
            config: Arc::new(Mutex::new(WarmingConfig::default())),
            stats: Arc::new(Mutex::new(WarmingStats::default())),
        }
    }
}

impl Default for WarmingConfig {
    fn default() -> Self {
        Self {
            cache_size_limit: 256 * 1024 * 1024, // 256MB
            ttl_seconds: 3600, // 1 hour
            preload_queries: Vec::new(),
            warming_strategy: WarmingStrategy::Lazy,
            eviction_policy: EvictionPolicy::LRU,
            background_warming: true,
        }
    }
}

impl Default for WarmingStats {
    fn default() -> Self {
        Self {
            cache_hits: 0,
            cache_misses: 0,
            evictions: 0,
            warming_operations: 0,
            total_warming_time_ms: 0,
            memory_usage_bytes: 0,
        }
    }
}

/// Create a new index warming resource
#[rustler::nif]
pub fn index_warming_new() -> NifResult<ResourceArc<IndexWarmingResource>> {
    let resource = ResourceArc::new(IndexWarmingResource::new());
    Ok(resource)
}

/// Configure warming settings
#[rustler::nif]
pub fn index_warming_configure(
    warming_resource: ResourceArc<IndexWarmingResource>,
    cache_size_mb: usize,
    ttl_seconds: u64,
    strategy: String,
    eviction_policy: String,
    background_warming: bool,
) -> NifResult<Atom> {
    let strategy = match strategy.as_str() {
        "eager" => WarmingStrategy::Eager,
        "lazy" => WarmingStrategy::Lazy,
        "scheduled" => WarmingStrategy::Scheduled,
        "predictive" => WarmingStrategy::Predictive,
        _ => return Err(Error::BadArg),
    };

    let eviction = match eviction_policy.as_str() {
        "lru" => EvictionPolicy::LRU,
        "lfu" => EvictionPolicy::LFU,
        "ttl" => EvictionPolicy::TTL,
        "size" => EvictionPolicy::Size,
        _ => return Err(Error::BadArg),
    };

    let mut config = warming_resource.config.lock().unwrap();
    config.cache_size_limit = cache_size_mb * 1024 * 1024;
    config.ttl_seconds = ttl_seconds;
    config.warming_strategy = strategy;
    config.eviction_policy = eviction;
    config.background_warming = background_warming;

    Ok(rustler::types::atom::ok())
}

/// Add preload queries for warming
#[rustler::nif]
pub fn index_warming_add_preload_queries(
    warming_resource: ResourceArc<IndexWarmingResource>,
    queries: Vec<String>,
) -> NifResult<Atom> {
    let mut config = warming_resource.config.lock().unwrap();
    config.preload_queries.extend(queries);
    Ok(rustler::types::atom::ok())
}

/// Warm an index with preload queries
#[rustler::nif]
pub fn index_warming_warm_index(
    warming_resource: ResourceArc<IndexWarmingResource>,
    index_resource: ResourceArc<IndexResource>,
    cache_key: String,
) -> NifResult<Atom> {
    let start_time = Instant::now();
    let config = warming_resource.config.lock().unwrap().clone();

    let reader = index_resource.index.reader().map_err(|_| Error::BadArg)?;
    let searcher = reader.searcher();

    // Estimate searcher size (simplified)
    let size_bytes = 1024 * 1024; // Placeholder estimation

    let cached_searcher = CachedSearcher {
        searcher: Arc::new(searcher),
        created_at: Instant::now(),
        access_count: 0,
        last_accessed: Instant::now(),
        size_bytes,
    };

    // Cache the warmed searcher
    let mut cache = warming_resource.cache.lock().unwrap();
    cache.insert(cache_key, cached_searcher);

    // Update stats
    let mut stats = warming_resource.stats.lock().unwrap();
    stats.warming_operations += 1;
    stats.total_warming_time_ms += start_time.elapsed().as_millis() as u64;
    stats.memory_usage_bytes += size_bytes;        // Run preload queries if configured
        if config.background_warming {
            let queries = config.preload_queries.clone();
            let _warming_resource_clone = warming_resource.clone();

            thread::spawn(move || {
                for _query in queries {
                    // Simulate query execution for warming
                    thread::sleep(Duration::from_millis(1));
                }
            });
        }

    Ok(rustler::types::atom::ok())
}

/// Get a cached searcher
#[rustler::nif]
pub fn index_warming_get_searcher(
    warming_resource: ResourceArc<IndexWarmingResource>,
    cache_key: String,
) -> NifResult<ResourceArc<SearcherResource>> {
    let mut cache = warming_resource.cache.lock().unwrap();
    let mut stats = warming_resource.stats.lock().unwrap();

    if let Some(cached_searcher) = cache.get_mut(&cache_key) {
        // Update access statistics
        cached_searcher.access_count += 1;
        cached_searcher.last_accessed = Instant::now();
        stats.cache_hits += 1;

        // Create searcher resource
        let searcher_resource = SearcherResource {
            searcher: cached_searcher.searcher.clone(),
        };

        Ok(ResourceArc::new(searcher_resource))
    } else {
        stats.cache_misses += 1;
        Err(Error::BadArg)
    }
}

/// Evict cached entries based on policy
#[rustler::nif]
pub fn index_warming_evict_cache(
    warming_resource: ResourceArc<IndexWarmingResource>,
    force_all: bool,
) -> NifResult<usize> {
    let config = warming_resource.config.lock().unwrap().clone();
    let mut cache = warming_resource.cache.lock().unwrap();
    let mut stats = warming_resource.stats.lock().unwrap();

    let mut evicted_count = 0;

    if force_all {
        evicted_count = cache.len();
        cache.clear();
        stats.memory_usage_bytes = 0;
    } else {
        let now = Instant::now();
        let ttl_duration = Duration::from_secs(config.ttl_seconds);

        cache.retain(|_key, cached_searcher| {
            let should_evict = match config.eviction_policy {
                EvictionPolicy::TTL => now.duration_since(cached_searcher.created_at) > ttl_duration,
                EvictionPolicy::LRU => now.duration_since(cached_searcher.last_accessed) > ttl_duration,
                _ => false, // Simplified for other policies
            };

            if should_evict {
                evicted_count += 1;
                stats.memory_usage_bytes = stats.memory_usage_bytes.saturating_sub(cached_searcher.size_bytes);
            }

            !should_evict
        });
    }

    stats.evictions += evicted_count as u64;
    Ok(evicted_count)
}

/// Get warming and caching statistics
#[rustler::nif]
pub fn index_warming_get_stats(
    warming_resource: ResourceArc<IndexWarmingResource>,
) -> NifResult<String> {
    let stats = warming_resource.stats.lock().unwrap();
    let cache = warming_resource.cache.lock().unwrap();

    let response = serde_json::json!({
        "cache_hits": stats.cache_hits,
        "cache_misses": stats.cache_misses,
        "hit_ratio": if stats.cache_hits + stats.cache_misses > 0 {
            stats.cache_hits as f64 / (stats.cache_hits + stats.cache_misses) as f64
        } else {
            0.0
        },
        "evictions": stats.evictions,
        "warming_operations": stats.warming_operations,
        "total_warming_time_ms": stats.total_warming_time_ms,
        "average_warming_time_ms": if stats.warming_operations > 0 {
            stats.total_warming_time_ms / stats.warming_operations
        } else {
            0
        },
        "memory_usage_bytes": stats.memory_usage_bytes,
        "cached_entries": cache.len(),
    });

    Ok(response.to_string())
}

/// Clear all cached entries
#[rustler::nif]
pub fn index_warming_clear_cache(
    warming_resource: ResourceArc<IndexWarmingResource>,
) -> NifResult<Atom> {
    let mut cache = warming_resource.cache.lock().unwrap();
    let mut stats = warming_resource.stats.lock().unwrap();

    let evicted_count = cache.len();
    cache.clear();
    stats.evictions += evicted_count as u64;
    stats.memory_usage_bytes = 0;

    Ok(rustler::types::atom::ok())
}
