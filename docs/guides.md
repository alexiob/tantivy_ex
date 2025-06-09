# TantivyEx Guides

A comprehensive collection of guides to help you get the most out of TantivyEx, from basic setup to advanced production deployment.

## Quick Navigation

- **New to TantivyEx?** Start with [Installation & Setup](installation-setup.md)
- **Want to try it out?** Jump to [Quick Start Tutorial](quick-start.md)
- **Need to understand the basics?** Read [Core Concepts](core-concepts.md)
- **Want analytics and reporting?** Explore [Aggregations](aggregations.md)
- **Need horizontal scaling?** Check out [Distributed Search](otp-distributed-implementation.md)
- **Performance issues?** Check [Performance Tuning](performance-tuning.md)
- **Going to production?** Review [Production Deployment](production-deployment.md)
- **Building integrations?** Explore [Integration Patterns](integration-patterns.md)

## Complete Guide Index

### 📚 Getting Started

#### [Installation & Setup](installation-setup.md)

Learn how to install and configure TantivyEx in your Elixir application. Covers basic installation, configuration options, and verification steps.

**Key Topics:**

- Basic installation with Mix
- Configuration options
- Environment setup
- Common installation issues

#### [Quick Start Tutorial](quick-start.md)

A hands-on tutorial that walks you through creating your first search index, adding documents, and performing searches. Perfect for getting a feel for TantivyEx.

**Key Topics:**

- Creating your first index
- Adding and updating documents
- Basic search operations
- Understanding search results

### 🏗️ Understanding TantivyEx

#### [Core Concepts](core-concepts.md)

Deep dive into the fundamental concepts that power TantivyEx. Essential reading for understanding how everything works together.

**Key Topics:**

- Schemas and field types
- Document structure
- Indexing process
- Search mechanics
- Tokenization

### ⚡ Optimization & Performance

#### [Performance Tuning](performance-tuning.md)

Comprehensive guide to optimizing TantivyEx for your specific use case. Learn about indexing performance, search optimization, and memory management.

**Key Topics:**

- Indexing performance optimization
- Search query optimization
- Memory management
- Monitoring and profiling
- Hardware considerations

#### [Production Deployment](production-deployment.md)

Everything you need to know about deploying TantivyEx in production environments. Covers scalability, monitoring, backup strategies, and operational best practices.

**Key Topics:**

- Production configuration
- Scalability patterns
- Monitoring and observability
- Backup and recovery
- Security considerations
- Operational procedures

### 🔧 Advanced Topics

#### [Aggregations](aggregations.md)

Comprehensive guide to data aggregation and analytics using TantivyEx. Learn how to perform complex data analysis, generate reports, and extract insights from your search data.

**Key Topics:**

- Bucket aggregations (terms, histogram, date_histogram, range)
- Metric aggregations (avg, min, max, sum, stats, percentiles)
- Nested aggregations and sub-aggregations
- Elasticsearch-compatible aggregation API
- Performance optimization for large datasets
- Real-world examples and use cases

#### [Distributed Search](otp-distributed-implementation.md

Complete guide to distributed search capabilities in TantivyEx. Learn how to coordinate search operations across multiple nodes, implement load balancing, and scale horizontally.

**Key Topics:**

- Distributed search coordinator setup
- Node management and load balancing
- Result merging strategies
- Cluster health monitoring
- Failover and error handling
- Performance optimization for distributed environments
- Integration patterns with Phoenix and GenServer

#### [Integration Patterns](integration-patterns.md)

Advanced patterns for integrating TantivyEx with web frameworks, databases, and other systems. Learn about real-time indexing, distributed search, and complex architectures.

**Key Topics:**

- Phoenix/LiveView integration
- Database synchronization
- Real-time indexing patterns
- Distributed search architectures
- Event-driven indexing
- Custom tokenizers and analyzers

## Additional Resources

### API Documentation

- [Schema Management](schema.md)
- [Document Operations](documents.md)
- [Indexing](indexing.md)
- [Search Operations](search.md)
- [Search Results](search_results.md)
- [Tokenizers](tokenizers.md)
- [Aggregations](aggregations.md)
- [OTP Distributed Search](otp-distributed-implementation.md)

### Community & Support

- [GitHub Repository](https://github.com/tantivyproject/tantivy-ex)
- [Elixir Forum](https://elixirforum.com/)
- [Tantivy Documentation](https://docs.rs/tantivy/)

---

*This guide index provides a comprehensive overview of all TantivyEx documentation. Each guide is designed to be self-contained while providing cross-references to related topics.*
