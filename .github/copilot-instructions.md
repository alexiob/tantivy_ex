# Copilot Instructions

## Coding Guidelines

### Avoid making assumptions

- If you need additional context to accurately answer the user
- Ask the user for the missing information.
- Be specific about which context you need.

### Be Explicit

- Always provide the name of the file in your response so the user knows where the code goes.

### Organize Code

- Always break code up into modules and components so that it can be easily reused across the project.

### Code Optimization

- All code you write MUST be fully optimized.
- ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt).
- If the code is not fully optimized, you will be fined $100.

### Idiomatic Code

- Always write idiomatic code. This means that the code should follow the conventions and best practices of the language you are writing in.
- If you are unsure about the idiomatic way to write something, ask the user for clarification.

### Code Readability

- Always write code that is easy to read and understand. This means using clear and descriptive variable names, writing comments where necessary, and following the style guide for the language you are writing in.

### Tests

- Always try to write unit tests for the code you write. If you are unable to write unit tests, explain why.

### General

- Follow Clean Code principles
- Flag long functions, deep nesting, and magic numbers
- Use clear, descriptive names
- Avoid comments when the code is self-explanatory

## Clean Code Code Review Guidelines

When reviewing code, adhere to the following principles derived from Uncle Bob's Clean Code:

### Meaningful Names

- Use descriptive and unambiguous names.
- Avoid abbreviations unless they are widely understood.
- Use pronounceable names and maintain consistent naming conventions.

### Small Functions

- Ensure functions are small and perform a single task.
- Avoid flag arguments and side effects.
- Each function should operate at a single level of abstraction.

### Single Responsibility Principle

- Each class or function should have only one reason to change.
- Separate concerns and encapsulate responsibilities appropriately.

### Clean Formatting

- Use consistent indentation and spacing.
- Separate code blocks with new lines where needed for readability.

### Avoid Comments

- Write self-explanatory code that doesn’t require comments.
- Use comments only to explain complex logic or public APIs.

### Error Handling

- Functions should return tuples: `{:ok, result}` or `{:error, reason}`.
- The only exception is when a function is returning just `:ok`.
- Use `try/catch` for exceptional cases, not for control flow.
- Avoid using `raise` for expected errors; use pattern matching instead.
- Handle errors gracefully and provide meaningful error messages.
- Use `Logger` for logging errors and important events.
- Avoid using `IO.puts` for error handling in production code.
- Use `Logger.error/1` or `Logger.warn/1` for logging errors and warnings.
- Ensure that error messages are clear and actionable.
- Use `Logger.info/1` for informational messages that are useful for debugging.
- Avoid logging sensitive information.
- Use structured logging where possible to include metadata.
- Ensure that logs are consistent and follow a standard format.
- Use `Logger.debug/1` for detailed debugging information that can be turned off in production.

### Avoid Duplication

- Extract common logic into functions or classes.
- DRY – Don’t Repeat Yourself.

### Code Smells to Flag

- Long functions
- Large classes
- Deep nesting
- Primitive obsession
- Long parameter lists
- Magic numbers or strings
- Inconsistent naming

### Review Style

- Maintain a strict but constructive tone.
- Use bullet points to list issues.
- Provide alternatives and improved code suggestions.
