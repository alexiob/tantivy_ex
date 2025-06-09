# TantivyEx Distributed Search

This document outlines the OTP-based distributed search implementation for TantivyEx, leveraging Elixir's robust OTP features for fault-tolerant, scalable distributed search coordination.

## Architecture Overview

The TantivyEx distributed search system is built using Elixir's OTP (Open Telecom Platform) patterns, providing:

| Feature | Implementation |
|---------|----------------|
| Coordination | Elixir GenServers |
| Fault Tolerance | Full OTP supervision trees |
| State Management | Structured Elixir state |
| Concurrency | Elixir processes |
| Monitoring | Built-in health checks |
| Scalability | Dynamic supervision |

## OTP Supervision Tree

```
TantivyEx.Distributed.Supervisor
├── Registry (Node discovery)
├── Coordinator (GenServer - orchestration)
├── NodeSupervisor (DynamicSupervisor - node management)
│   ├── SearchNode (GenServer per node)
│   └── SearchNode (GenServer per node)
└── TaskSupervisor (Concurrent operations)
```

## Key Benefits

### 1. **Fault Tolerance**

- Automatic process restart on failures
- Supervisor strategies for different failure scenarios
- Graceful degradation when nodes fail
- Built-in circuit breaker patterns

### 2. **Scalability**

- Dynamic node addition/removal
- Process-per-node isolation
- Horizontal scaling through distributed Erlang
- Load balancing at the process level

### 3. **Monitoring & Observability**

- Built-in process monitoring
- Health check integration
- Performance metrics collection
- Real-time cluster status

### 4. **Maintainability**

- Pure Elixir implementation
- Standard OTP patterns
- Clear separation of concerns
- Better testing capabilities

## Implementation Details

### Core Components

#### 1. Supervisor (`TantivyEx.Distributed.Supervisor`)

- Manages the entire distributed search infrastructure
- Implements fault tolerance strategies
- Handles system initialization and shutdown

#### 2. Coordinator (`TantivyEx.Distributed.Coordinator`)

- Central orchestration GenServer
- Manages cluster configuration
- Handles search request distribution
- Implements merge strategies

#### 3. SearchNode (`TantivyEx.Distributed.SearchNode`)

- Individual node GenServer
- Manages local Tantivy searcher
- Handles health monitoring
- Tracks performance metrics

#### 4. Registry

- Service discovery for nodes
- Process tracking and naming
- Dynamic node registration

### Search Flow

1. **Request Reception**: Coordinator receives search request
2. **Node Selection**: Apply load balancing strategy to select active nodes
3. **Concurrent Execution**: Task.Supervisor manages parallel searches
4. **Result Collection**: Gather results with timeout handling
5. **Merge Strategy**: Apply configured merge algorithm
6. **Response Formation**: Return unified response with metadata

### Load Balancing Strategies

#### Round Robin

```elixir
defp select_nodes_round_robin(active_nodes, state) do
  count = length(active_nodes)
  index = rem(state.node_round_robin_counter, count)
  selected = Enum.at(active_nodes, index)
  {[selected], %{state | node_round_robin_counter: index + 1}}
end
```

#### Weighted Round Robin

```elixir
defp select_nodes_weighted(active_nodes, _state) do
  total_weight = Enum.sum(Enum.map(active_nodes, & &1.weight))
  # Implement weighted selection logic
end
```

#### Health-Based

```elixir
defp select_healthy_nodes(active_nodes, _state) do
  Enum.filter(active_nodes, fn node ->
    SearchNode.get_health_status(node.pid) == :healthy
  end)
end
```

### Health Monitoring

Each SearchNode performs periodic health checks:

```elixir
def handle_info(:health_check, state) do
  health_status = perform_health_check(state.searcher)

  # Auto-deactivate unhealthy nodes
  new_state = case health_status do
    :unhealthy -> %{state | active: false}
    :healthy -> %{state | active: true}
    _ -> state
  end

  {:noreply, new_state}
end
```

## Migration Plan

### Phase 1: Parallel Implementation

- [x] Create OTP-based modules alongside existing native implementation
- [x] Implement core functionality (Supervisor, Coordinator, SearchNode)
- [x] Add comprehensive test suite
- [x] Create clean API interface (`TantivyEx.Distributed.OTP`)

### Phase 2: Feature Parity

- [ ] Implement all merge strategies
- [ ] Add advanced load balancing algorithms
- [ ] Create performance benchmarks
- [ ] Add configuration validation
- [ ] Implement distributed Erlang support

### Phase 3: Migration & Deprecation

- [ ] Update documentation to recommend OTP implementation
- [ ] Add migration utilities
- [ ] Deprecate native implementation
- [ ] Remove native coordination code

## Usage Examples

### Basic Setup

```elixir
# Start the distributed search system
{:ok, _pid} = TantivyEx.Distributed.OTP.start_link()

# Add search nodes
:ok = TantivyEx.Distributed.OTP.add_node("node1", "local://index1", 1.0)
:ok = TantivyEx.Distributed.OTP.add_node("node2", "local://index2", 1.5)

# Configure behavior
:ok = TantivyEx.Distributed.OTP.configure(%{
  timeout_ms: 5000,
  merge_strategy: :score_desc,
  health_check_interval: 30_000
})
```

### Advanced Configuration

```elixir
# Custom supervision tree
opts = [
  name: MyApp.DistributedSearch,
  coordinator_name: MyApp.SearchCoordinator,
  registry_name: MyApp.SearchRegistry
]

{:ok, _pid} = TantivyEx.Distributed.OTP.start_link(opts)

# Bulk node addition
nodes = [
  {"primary", "local://primary_index", 3.0},
  {"secondary", "local://secondary_index", 2.0},
  {"cache", "local://cache_index", 1.0}
]

:ok = TantivyEx.Distributed.OTP.add_nodes(nodes)
```

### Production Deployment

```elixir
# Application supervisor integration
children = [
  {TantivyEx.Distributed.OTP,
   name: MyApp.Search,
   coordinator_name: MyApp.SearchCoordinator}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Performance Considerations

### Memory Usage

- Each SearchNode maintains its own state
- Registry overhead is minimal
- Process memory isolation prevents memory leaks

### Latency

- Process message passing adds minimal latency (~1-5µs)
- Concurrent execution reduces overall response time
- Task supervision enables timeout handling

### Throughput

- Multiple concurrent searches supported
- Process-per-node enables true parallelism
- No global locks or bottlenecks

## Testing Strategy

### Unit Tests

- Individual component testing (GenServers, functions)
- Mock implementations for external dependencies
- Property-based testing for merge algorithms

### Integration Tests

- End-to-end search flow testing
- Failure scenario testing
- Performance benchmarking

### Fault Tolerance Tests

- Process crash simulation
- Network partition testing
- Recovery time measurement

## Future Enhancements

### Distributed Erlang

- Multi-node cluster support
- Automatic node discovery
- Cross-node failover

### Advanced Monitoring

- Telemetry integration
- Metrics export (Prometheus, etc.)
- Real-time dashboards

### Smart Load Balancing

- Machine learning-based routing
- Adaptive algorithms
- Geographic distribution

## Conclusion

The OTP-based implementation provides a more robust, scalable, and maintainable foundation for distributed search in TantivyEx. By leveraging Elixir's battle-tested concurrency model and fault tolerance mechanisms, we achieve better reliability and performance while maintaining clean, idiomatic Elixir code.

This implementation serves as a foundation for future enhancements and provides a clear migration path from the native coordination approach.
