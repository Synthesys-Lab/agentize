---
paths: "**/*.md"
---

# DSA Stack Documentation Guidelines

## Document Format
Unless otherwise specified, all documentation must be in Markdown format.

## Directory Documentation Organization Principles

### README.md Requirements for Every Directory

**Core Principle**: Every directory in the project MUST have a README.md file that serves as the entry point for understanding that directory's purpose and contents.

### README.md Structure Requirements

Every `README.md` file must consist of three main parts, presented in this order:

#### Directory Functionality and Key Concepts
- Explain the core purpose and functionality of the directory.
- Provide a conceptual overview.
- **Offload Rule**: If this section becomes too long, it can be offloaded to a **local, flat `docs/` subdirectory** as single or multiple files (e.g., `docs/directory-overview.md`, `docs/directory-concepts.md`, `docs/directory-architecture.md`) with appropriate links in the `README.md`.

#### File Descriptions
- Document the functionality of each file within the current directory.
- **Version Control Exclusion Rule**: Files ignored by `.gitignore` (from either the root directory or current directory) should NOT be included in the documentation.
- **Empty Directory Rule**: If the current directory contains no files (only subdirectories), include a brief statement: "This directory contains no files, only subdirectories described below."
- **Offload Rule**: If this section would make the `README.md` too long, create a **local, flat `docs/` subdirectory** to offload content.
- **All-or-nothing principle**: If using a local `docs/` subdirectory, ALL detailed file descriptions must be moved into it as dedicated documentation files (`docs/File_A.md`, `docs/File_B.md`, etc.).
- **No mixing**: Do NOT put some file descriptions in the `README.md` and others in separate `docs/` files.

#### Subdirectory Overview
- This part is **MANDATORY** in the main `README.md`.
- Provide a one-sentence summary of each subdirectory's functionality.
- Include links to each subdirectory's `README.md` (e.g., `[Folder_1 README]` pointing to `./Folder_1/README.md`).
- **Version Control Exclusion Rule**: Directories ignored by `.gitignore` (from either the root directory or current directory) should NOT be included in the documentation.
- **Empty Directory Rule**: If the current directory contains no subdirectories (only files), include a brief statement: "This directory contains no subdirectories."
- **Cannot be moved to docs/**: This part MUST always remain in the main `README.md`.

### Documentation Distribution Strategy: Local `docs/` Offloading

#### Permitted Pattern: Local, Flat `docs/` Subdirectory
- **Purpose**: To keep the parent `README.md` concise by offloading lengthy content from its "Directory Functionality and Key Concepts" (single or multiple concept files) or "File Descriptions" parts.
- **Location**: A `docs/` subdirectory may be created within any project directory, at the same level as the `README.md` it supports.
- **CRITICAL CONSTRAINT**: This `docs/` subdirectory **MUST be flat**. It cannot contain its own subdirectories. Its purpose is solely for content offloading, not for creating a complex documentation hierarchy.

#### Prohibited Pattern: Global, Nested `docs/` Directory
- A single, top-level `docs/` directory for the entire project is **strictly prohibited**.
- The project's documentation is designed to be distributed and co-located with the relevant code and modules, not centralized in one location.

### Markdown File Length Guidelines

These guidelines apply to **ALL** markdown files (`.md`) in the repository, including `README.md` and any files within local `docs/` subdirectories.

- **Preferred Length**: <1000 lines
- **Maximum Length**: 1500 lines
- **Action on Exceeding Max Length**:
  - For a `README.md`, offload content to a local `docs/` subdirectory as described above.
  - For a file within a `docs/` subdirectory, it must be split into multiple, more focused files within the same flat `docs/` directory.

### Cross-Directory Consistency

#### Navigation Requirements
- Every README.md must provide clear navigation to:
  - Parent directory functionality
  - Subdirectory purposes and their README.md files
  - Related directories when relevant

#### Documentation Discoverability
- Documentation structure should enable developers to understand any directory's purpose within 30 seconds
- Clear hierarchical navigation from project root to specific functionality

## Directory Documentation Maintenance Requirements

### README.md Update Requirements

**CRITICAL REQUIREMENT**: When directory contents change, the corresponding README.md MUST be updated immediately.

#### What requires README.md updates:

1. **Adding new files**: Update the "File Descriptions" part to include new files.
2. **Removing files**: Remove corresponding file descriptions from the "File Descriptions" part.
3. **Adding new subdirectories**: Update the "Subdirectory Overview" part with new subdirectory navigation.
4. **Removing subdirectories**: Remove corresponding subdirectory references from the "Subdirectory Overview" part.
5. **Renaming files or directories**: Update all references throughout the `README.md`.
6. **Creating a `docs/` subdirectory**: Switch from inline content (file descriptions or directory functionality) to `docs/` file references with appropriate links.

#### Verification steps:

1. After making changes to a directory's structure, immediately check its `README.md`.
2. Ensure all three parts are accurate:
   - The "Directory Functionality and Key Concepts" part remains current (whether inline or offloaded to docs/).
   - The "File Descriptions" part matches the actual files in the directory.
   - The "Subdirectory Overview" part has valid and working links to all subdirectories.
3. Test that all internal links work correctly.
4. Verify navigation to parent and child directories is maintained.

#### Special Cases:

- **`docs/` subdirectory creation**: When content (file descriptions or directory functionality) becomes too long and a `docs/` subdirectory is created, ALL content of that type must be moved to appropriate `docs/` files with proper linking from the `README.md`.
- **Directory functionality offloading**: If the "Directory Functionality and Key Concepts" part becomes too long, it can be offloaded to one or more dedicated files within the local `docs/` subdirectory (e.g., `docs/directory-overview.md`, `docs/directory-concepts.md`, `docs/directory-architecture.md`), with the `README.md` containing a brief summary and appropriate links.
- **Cross-directory references**: Update any references in related directories when directory structure changes.

### DSA-CHARTER.md Maintenance (Limited Scope)

DSA-CHARTER.md should only be updated for **major structural changes** to the project, not for routine documentation updates:

- Adding/removing entire tool directories in `tools/`
- Major reorganization of top-level directories (e.g., `examples/`)
- Changes to overall project architecture

**Do NOT update DSA-CHARTER.md for**:
- Individual file additions/deletions within existing directories
- Documentation reorganization within tool directories
- Rule file changes
- README.md content updates

## General Documentation Design Principles
For all markdown (.md) documents in DSA Stack, follow these design principles:

### Interface-Focused Documentation
- Focus on explaining concepts, ideas, and design key points
- Documentation should emphasize function/file interfaces with simple but complete examples
- Define instructions and operations clearly
- Can describe folder hierarchy and file architecture (dependencies, inheritance relationships)

### Test-Driven Documentation Philosophy
- Avoid inserting implementation code (large code sections or detailed implementation classes/functions)
- Follow "test-driven development" philosophy: use simplest examples to clarify input/output for each feature
- Examples should focus on "writing tests" rather than describing implementation
- Show what the input should be, what the output should be, not how the feature is implemented
- **Important distinction**: Example code snippets that show key ideas, input/output formats, DSA dialect concepts, or transformations (MLIR, JSON, etc.) are encouraged and valuable

### Tool Documentation Structure
Every "tool" documentation must define in the first 100 lines:
- **Input specification**: What the tool accepts (with format specifications)
- **Output specification**: What the tool produces (with format specifications)
- **Functionality**: What the tool does
- Use simple but complete examples to illustrate:
  - Each field
  - Parameter samples
  - File formats (both instruction formats and input/output file serialization formats)
- For internal functionality:
  - Describe only core concepts
  - Use pseudocode when necessary to describe approach
  - Code in documentation should focus on explaining ideas, not implementation details

### Context Awareness Before Modification
Before modifying any document:
- Read the first 100 lines of all documents in the same directory
- Read the first 50 lines of documents in the parent directory
- Determine if changes require updates to other documents
- Add TODOs for necessary related changes after completing current modifications

### Visual Representations
- Use Mermaid format for diagrams (flowcharts, state diagrams, architecture diagrams) when they help explain concepts
- Mermaid nodes must use meaningful names, not single letters

#### Mermaid State Diagram Notes
When adding notes to Mermaid state diagrams, use the proper multi-line syntax:

**Correct syntax:**
```mermaid
note right of STATE_NAME
  First line of note
  Second line of note
  Third line of note
end note
```

**Incorrect syntax:**
```mermaid
note right of STATE_NAME: Line1\nLine2\nLine3
```

The multi-line syntax provides better readability and proper formatting in rendered diagrams.

#### Interface Timing Specifications

When documenting hardware interface timing, use the appropriate format based on complexity:

**Simple waveforms (≤3 signals, ≤5 cycles):** Use ASCII waveforms:
```
     0   1   2   3   4
clk  _/‾\_/‾\_/‾\_/‾\_
req  ____/‾‾‾‾‾\______
ack  ______/‾‾‾\______
```

**Complex waveforms (>3 signals or >5 cycles):** Use WaveDrom via svg.wavedrom.com:
```markdown
![waveform](https://svg.wavedrom.com/{signal:[{name:'clk',wave:'p......'},{name:'req',wave:'01..0..'},{name:'ack',wave:'0.1.0..'}]})
```

This renders as a proper timing diagram in GitHub markdown without requiring local tooling. Demo like below:
![waveform](https://svg.wavedrom.com/{signal:[{name:'clk',wave:'p......'},{name:'req',wave:'01..0..'},{name:'ack',wave:'0.1.0..'}]})

**Always include prose descriptions:** Waveforms alone cannot express protocol semantics and edge cases. Always accompany timing diagrams with brief prose describing:
- Handshake requirements (e.g., "ack must arrive within 4 cycles or timeout triggers")
- Signal dependencies and ordering constraints
- Error handling and recovery sequences

### Hardware Implementation Guidance vs Results
Documentation should NOT include:
- Vendor-specific performance metrics (e.g., resource usage on specific FPGA devices, technology nodes)
- Implementation results or measurements from actual hardware
- Large blocks of implementation code (RTL, detailed Verilog/VHDL)
- Fabricated performance percentages or quantitative improvements without basis

Documentation SHOULD include:
- **Module composition**: What sub-modules make up this module
- **Critical path identification**: Which sub-modules may create timing bottlenecks or resource overhead
- **Implementation alternatives**: Options like SRAM vs registers, low-power design considerations
- **Design trade-off considerations**: Specific architectural choices and their qualitative PFAC implications
  - Example: "Pipeline depth between decoder and execution units can be adjusted based on target frequency vs latency requirements"
  - Example: "Memory interface width presents area vs bandwidth trade-off"
  - Example: "Consider dynamic clock gating for idle submodules to reduce power consumption"
- **Optimization strategies**: Directions and angles for potential improvements without claiming specific results

Core principle: Documentation provides "design considerations and trade-off strategies", NOT "performance results or quantitative claims"

This section encodes a persistent project convention.

## Concise Documentation Style
The user prefers documentation to be concise and descriptive, focusing on describing ideas and functionality with small examples rather than large implementation code blocks. If pseudocode is needed (to show key concepts or ideas), then it is fine.

## Centralized Data Type Definitions
The user prefers to centralize standard data type definitions in `docs/architecture/dsa-dialect.md` and have other documentation files throughout the project reference it rather than duplicating definitions across files.

## Markdown Heading Format

Markdown documentation should only use the number of # symbols to indicate section hierarchy, without adding numerical prefixes.

**Correct**:
```markdown
# Architecture Overview
## Software Support
### Key Features
```

**Incorrect**:
```markdown
# 1. Architecture Overview
## 1.1 Software Support
### 1.1.1 Key Features
```

This maintains clean, standard Markdown structure and prevents redundancy between the heading level and explicit numbering.

## Internal Cross-References

When referencing other sections within the same document, use markdown anchor links instead of plain section numbers or names.

**Correct** (using anchor links like `#section-name`):

    For more details, see [Document Format](#document-format) for format specs.
    Please refer to [Concise Documentation Style](#concise-documentation-style).

**Incorrect**:
```markdown
For more details, see Section 1-4 for system design.
Please refer to Sections 1-4 for architecture details.
```

This approach:
- Creates clickable navigation within documents
- Remains valid even when section order changes
- Provides better user experience in both web and offline viewers
- Follows standard markdown practices

## Hardware Module Documentation Pattern

### Applicability

This section applies only to markdown documents that describe a specific, concrete hardware module's architecture (one module per document).

Out of scope (this rule does not apply):
- Overview/umbrella/summary documents that aggregate or compare multiple modules
- General tool documentation or high-level architecture guides that are not focused on a single module

### Required Sections for Hardware Module Documents

Overview and Interface
   - Purpose, assumptions, inputs/outputs
   - Parameter list with types and meanings

Parameter Validation Rules
   - Explicit constraints and valid ranges
   - Describe compile-time vs runtime checks

Functional and Structural Description
   - High-level functionality: what the module is designed to do and its role in the system
   - Interface behavior: how inputs are transformed into outputs (logic flow, timing assumptions)
   - Internal organization: block-level description of internal components and their responsibilities
   - Submodules: list and explain each submodule, its role, and how it connects with others
   - Interaction model: data/control flow across submodules, including pipeline/handshake protocols

PFAC Tradeoffs
   - Present design considerations and trade-off directions for power, frequency, area, and cycle optimization
   - Focus on architectural choices and their qualitative PFAC implications
   - See detailed PFAC guidelines below

Resource Sharing Strategy
   - What resources can/should be shared across operations/modules
   - Arbitration/serialization policies and their PFAC implications

Critical Paths and Bottlenecks
   - Likely timing/resource hotspots and mitigation options

Alternatives and Microarchitecture Options
   - e.g., SRAM vs registers; pipelining choices; low-power modes

Parameter Validation Rules
   - Must follow two-stage validation framework:
     - Stage 1: Compile-time (hardware generation) checks for invalid hardware parameters
     - Stage 2: Runtime (configuration port) checks for invalid configuration values
   - Include specific error codes for different validation failures
   - Provide SystemVerilog examples for compile-time checks
   - Show RTL implementation for runtime validation

Minimal Examples / Tests
   - Small, interface-focused examples that clarify input/output behavior

## PFAC Design Considerations Guidelines

### Core Principle

PFAC Impact in hardware documentation should focus on design considerations and trade-off directions rather than fabricated performance data.

### Good Examples of PFAC Content

- "Consider merging pipeline stages between submodules when logic is minimal to optimize behavioral performance (C)"
- "Consider clock gating for idle modules to reduce power consumption (P)"
- "Shared arbiters between channels reduce area (A) at potential frequency cost (F)"
- "Pipeline depth between decoder and execution units can be adjusted based on target frequency vs latency requirements"
- "Memory interface width presents area vs bandwidth trade-off"
- "Since address generation may be idle during burst data returns, consider clock gating logic for power optimization (P)"
- "Shared arbiter between channels X and Y could reduce area (A) at the cost of potential frequency bottleneck (F)"

### What to Avoid in PFAC Tradeoffs

- Specific performance percentages without measurement basis
- Quantitative claims like "reduces power by X%"
- Vendor-specific optimization results
- Technology-dependent metrics

### What to Include in PFAC Tradeoffs

- Architectural trade-off strategies
- Optimization angles and directions
- Design alternatives with qualitative PFAC implications
- Resource sharing considerations
- Critical path identification
- Microarchitecture options

Documentation should list strategies, optimization angles, and architectural choices with qualitative PFAC implications, not quantitative performance percentages.

# Quantitative Data Guidelines for DSA Documentation

## Core Principle

Good documentation should guide work, define scope and boundaries, explain capabilities and limitations, and express functionality through minimal input/output examples - NOT fabricate quantitative metrics.

## Strict Prohibitions

1. **No Fabricated Performance Numbers**: Never include specific performance percentages, time measurements, or quantitative improvements without actual measurement data
   - [ERROR] Bad: "Reduces power by 30%"
   - [OK] Good: "Provides power optimization opportunities through clock gating"

2. **No Premature Quantification**: Avoid specific time/resource numbers in design documentation
   - [ERROR] Bad: "Smoke tests complete in 5 minutes"
   - [OK] Good: "Smoke tests target minute-level completion for rapid CI/CD feedback"

3. **No Hypothetical Results**: Don't present assumed outcomes as facts
   - [ERROR] Bad: "Achieves 2x speedup over baseline"
   - [OK] Good: "Designed to improve throughput via parallel execution"

## Recommended Practices

1. **Use Qualitative Descriptions**: Express goals and constraints qualitatively
   - "Sub-hour runtime" instead of "45 minutes"
   - "Minute-level" instead of "5 minutes"
   - "Extended periods" instead of "8 hours"

2. **Focus on Requirements and Constraints**: Describe what drives the design
   - "Due to rapid development needs..."
   - "Considering simulation runtime constraints..."
   - "To enable continuous integration..."

3. **Define Objectives, Not Metrics**: State what the system should achieve
   - "Quick sanity check for every code change"
   - "Comprehensive functional validation"
   - "Exhaustive coverage closure"

## Example Application

### Regression Test Levels (Correct Approach)

Instead of: "Smoke (5 min), Nightly (2 hours), Weekly (8 hours)"

Write: "Considering the need for rapid development iteration and the reality that some simulation tests may run for extended periods, the regression framework defines three test levels..."

Then describe each level by its objective, scope, and qualitative time target.

This guideline ensures documentation remains accurate, useful, and free from misleading quantitative claims.
